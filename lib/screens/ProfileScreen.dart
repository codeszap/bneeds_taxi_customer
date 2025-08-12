import 'package:bneeds_taxi_customer/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../widgets/common_drawer.dart';
import '../models/user_profile_model.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPrefsProvider = FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

final credentialsProvider = FutureProvider<Map<String, String>>((ref) async {
  final prefs = await ref.watch(sharedPrefsProvider.future);
  final username = prefs.getString('username') ?? '';
  final password = prefs.getString('password') ?? '';
  // return {
  //   'username': username,
  //   'password': password,
  // };

  return {'username': "ravi", 'password': "123"};
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credsAsync = ref.watch(credentialsProvider);

    return credsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading credentials: $err')),
      data: (creds) {
        if (creds['username']!.isEmpty || creds['password']!.isEmpty) {
          return const Center(child: Text('No saved credentials found'));
        }

        final profileAsync = ref.watch(fetchProfileProvider(creds));

        return Scaffold(
          backgroundColor: Colors.deepPurple.shade50,
          appBar: AppBar(
            title: const Text("My Profile"),
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
          drawer: CommonDrawer(onLogout: () {}),
          body: profileAsync.when(
            data: (profiles) {
              if (profiles.isEmpty) {
                return const Center(child: Text("No profile found"));
              }
              final profile = profiles.first;
              return RefreshIndicator(
                onRefresh: () async {
                  ref.refresh(fetchProfileProvider(creds));
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),  // padding moved here for better UX
                  child: _buildProfileView(context, ref, profile),
                ),
              );
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

  Widget _buildProfileView(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
  ) {
    // Parse the dob string (e.g., "8/4/2025 12:00:00 AM")
    DateTime? parsedDob;
    try {
      parsedDob = DateFormat("M/d/yyyy h:mm:ss a").parse(profile.dob);
    } catch (e) {
      parsedDob = null; // fallback if parsing fails
    }

    // Format the parsed date
    final formattedDob = parsedDob != null
        ? DateFormat("dd-MM-yyyy").format(parsedDob)
        : profile.dob; // fallback to original if parsing failed

    void _insertProfile(
      BuildContext context,
      WidgetRef ref,
      UserProfile profile,
    ) async {
      try {
        final result = await ref.read(insertProfileProvider(profile).future);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Insert successful: $result')));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Insert failed: $e')));
      }
    }

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

        const SizedBox(height: 30), // replaced Spacer with SizedBox

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              final manualProfile = UserProfile(
                userName: "mahesh",
                password: "12345",
                mobileNo: "9876543210",
                gender: "M",
                dob: "09-08-2025 10:00:00 AM",
                address1: "123 Street",
                address2: "Area",
                address3: "City",
                city: "Madurai",
              );
              _insertProfile(context, ref, manualProfile);
            },
            icon: const Icon(Icons.logout),
            label: const Text("Logout"),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              foregroundColor: Colors.deepPurple,
              side: BorderSide(color: Colors.deepPurple.shade300),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
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
}
