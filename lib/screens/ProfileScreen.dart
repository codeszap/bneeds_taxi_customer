import 'package:bneeds_taxi_customer/providers/profile_provider.dart';
import 'package:bneeds_taxi_customer/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../widgets/common_drawer.dart';
import '../models/user_profile_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPrefsProvider = FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

final credentialsProvider = FutureProvider<Map<String, String>>((ref) async {
  final prefs = await ref.watch(sharedPrefsProvider.future);
  final mobileno = prefs.getString('mobileno') ?? '';
  print("Fetched mobile number: $mobileno");
  return {'mobileno': mobileno};
});

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    // Just in case old provider data is there
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.refresh(credentialsProvider);
    });
  }


  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>(); // moved here ✅

  @override
  Widget build(BuildContext context) {
        final username = ref.watch(usernameProvider);
    final credsAsync = ref.watch(credentialsProvider);

    return credsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading credentials: $err')),
      data: (creds) {
        if (creds['mobileno']!.isEmpty) {
          return const Center(child: Text('No saved mobile number found'));
        }

        final profileAsync = ref.watch(
          fetchProfileProvider(creds['mobileno']!),
        );

// print("📦 Fetched credentials: ${creds['mobileno']} | Username: $username");
// print("📦 Profile async state: $profileAsync");
        return Scaffold(
          backgroundColor: Colors.deepPurple.shade50,
          appBar: AppBar(
            title: const Text("Profile"),
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            actions: [
              profileAsync.when(
                data: (profiles) {
                  if (profiles.isNotEmpty) {
                    return IconButton(
                      icon: Icon(_isEditing ? Icons.close : Icons.edit),
                      onPressed: () {
                        setState(() => _isEditing = !_isEditing);
                      },
                    );
                  }
                  return const SizedBox();
                },
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),
            ],
          ),
          drawer: CommonDrawer(),
          body: profileAsync.when(
            data: (profiles) {
              if (profiles.isEmpty || _isEditing) {
                return _buildProfileForm(
                  context,
                  ref,
                  creds['mobileno']!,
                  profiles.isNotEmpty ? profiles.first : null,
                );
              } else {
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.refresh(fetchProfileProvider(creds['mobileno']!));
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: _buildProfileView(context, profiles.first),
                  ),
                );
              }
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) {
              debugPrint('Profile fetch error: $err');
              debugPrint('Stack trace: $stack');
              return Center(child: Text("Failed to fetch profile: $err"));
            },
          ),
        );
      },
    );
  }

  Widget _buildProfileView(BuildContext context, UserProfile profile) {
    DateTime? parsedDob;
    try {
      parsedDob = DateFormat("M/d/yyyy h:mm:ss a").parse(profile.dob);
    } catch (_) {
      parsedDob = null;
    }

    final formattedDob = parsedDob != null
        ? DateFormat("dd-MM-yyyy").format(parsedDob)
        : profile.dob;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: Colors.deepPurple.shade200,
          child: const Icon(Icons.person, size: 40, color: Colors.white),
        ),
        const SizedBox(height: 12),
        Text(
          profile.userName,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        Text(
          "+91 ${profile.mobileNo}",
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 30),
        _profileTile(
          icon: Icons.person,
          title: "Gender",
          value: profile.gender,
        ),
        _profileTile(
          icon: Icons.location_on,
          title: "City",
          value: profile.city,
        ),
        _profileTile(
          icon: Icons.home,
          title: "Address",
          value:
              "${profile.address1}, ${profile.address2}, ${profile.address3}",
        ),
        _profileTile(
          icon: Icons.calendar_today,
          title: "DOB",
          value: formattedDob,
        ),
      ],
    );
  }

  Widget _profileTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.deepPurple),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDob(String dobString) {
    try {
      final parsed = DateTime.parse(dobString); // or use DateFormat if not ISO
      return DateFormat("dd-MM-yyyy").format(parsed);
    } catch (_) {
      return dobString; // fallback in case parsing fails
    }
  }

  Widget _buildProfileForm(
    BuildContext context,
    WidgetRef ref,
    String mobileNo,
    UserProfile? existingProfile,
  ) {
     final username = ref.watch(usernameProvider); // ✅ read username from provider

  final nameController = TextEditingController(
    text: existingProfile?.userName ?? username, // use provider value if available
  );

    final genderValue = ValueNotifier<String>(
      existingProfile?.gender.isNotEmpty == true
          ? existingProfile!.gender
          : "M",
    );
    final dobController = TextEditingController(
      text: existingProfile?.dob.isNotEmpty == true
          ? _formatDob(existingProfile!.dob)
          : "",
    );

    final address1Controller = TextEditingController(
      text: existingProfile?.address1 ?? "",
    );
    final address2Controller = TextEditingController(
      text: existingProfile?.address2 ?? "",
    );
    final address3Controller = TextEditingController(
      text: existingProfile?.address3 ?? "",
    );
    final cityController = TextEditingController(
      text: existingProfile?.city ?? "",
    );

    Future<void> _selectDate() async {
      DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime(2000, 1, 1),
        firstDate: DateTime(1900),
        lastDate: DateTime.now(),
      );
      if (picked != null) {
        dobController.text = DateFormat("dd-MM-yyyy").format(picked);
      }
    }

    Future<void> _saveProfile() async {
      if (_formKey.currentState!.validate()) {
        String formattedDob = dobController.text;
        try {
          formattedDob = DateFormat(
            "M/d/yyyy h:mm:ss a",
          ).format(DateFormat("dd-MM-yyyy").parse(dobController.text));
        } catch (_) {}

        final newProfile = UserProfile(
         userid: existingProfile?.userid ?? "",
          userName: nameController.text,
          password: "",
          mobileNo: mobileNo,
          gender: genderValue.value,
          dob: formattedDob,
          address1: address1Controller.text,
          address2: address2Controller.text,
          address3: address3Controller.text,
          city: cityController.text,
        );

        try {
          if (existingProfile == null) {
            print("Inserting new profile: $newProfile");
            await ref.read(insertProfileProvider(newProfile).future);
          } else {
            print("Updating existing profile: $newProfile");
            await ref.read(updateProfileProvider(newProfile).future);
          }

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isProfileCompleted', true);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile saved successfully')),
          );

          setState(() => _isEditing = false);
          ref.refresh(fetchProfileProvider(mobileNo));
          context.go("/home");
        } catch (e) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _styledTextField(nameController, "User Name"),
              ValueListenableBuilder<String>(
                valueListenable: genderValue,
                builder: (context, value, _) {
                  return DropdownButtonFormField<String>(
                    value: value,
                    items: const [
                      DropdownMenuItem(value: "M", child: Text("Male")),
                      DropdownMenuItem(value: "F", child: Text("Female")),
                      DropdownMenuItem(value: "O", child: Text("Other")),
                    ],
                    onChanged: (newVal) {
                      if (newVal != null) genderValue.value = newVal;
                    },
                    decoration: _dropdownDecoration("Gender"),
                  );
                },
              ),
              GestureDetector(
                onTap: _selectDate,
                child: AbsorbPointer(
                  child: _styledTextField(dobController, "Date of Birth"),
                ),
              ),
              _styledTextField(address1Controller, "Address Line 1"),
              _styledTextField(address2Controller, "Address Line 2"),
              _styledTextField(address3Controller, "Address Line 3"),
              _styledTextField(cityController, "City"),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Save Profile",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.deepPurple),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.deepPurple, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.deepPurple.shade200),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    );
  }

  Widget _styledTextField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.deepPurple),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.deepPurple, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.deepPurple.shade200),
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 16,
          ),
        ),
        validator: (value) =>
            value == null || value.isEmpty ? "Please enter $label" : null,
      ),
    );
  }
}
