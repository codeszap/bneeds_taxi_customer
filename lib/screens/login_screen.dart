import 'package:bneeds_taxi_customer/config/auth_service.dart' as authService;
import 'package:bneeds_taxi_customer/repositories/profile_repository.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../widgets/common_textfield.dart';
import '../widgets/common_button.dart';

final usernameProvider = StateProvider<String>((ref) => '');
final mobileProvider = StateProvider<String>((ref) => '');
final isLoadingProvider = StateProvider<bool>((ref) => false);

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final username = ref.watch(usernameProvider);
    final mobile = ref.watch(mobileProvider);
    final isFormValid = username.isNotEmpty && mobile.length == 10;

    return Scaffold(
      backgroundColor: Colors.deepPurple.shade50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// App Branding or Logo
                const SizedBox(height: 40),
                Center(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          width: 90,
                          height: 90,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Welcome Back!",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Login to continue your ride",
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 50),

                /// Username Field
                CommonTextField(
                  label: 'Username',
                  keyboardType: TextInputType.text,
                  onChanged: (val) =>
                      ref.read(usernameProvider.notifier).state = val,
                ),
                const SizedBox(height: 20),

                /// Mobile Field
                CommonTextField(
                  label: 'Mobile Number',
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  onChanged: (val) =>
                      ref.read(mobileProvider.notifier).state = val,
                ),
                const SizedBox(height: 20),

                /// Terms & Privacy
                Text.rich(
                  TextSpan(
                    text: 'By continuing, you agree to our ',
                    style: const TextStyle(color: Colors.black87, fontSize: 12),
                    children: [
                      TextSpan(
                        text: 'Terms of Service',
                        style: const TextStyle(
                          color: AppColors.secondaryBlue,
                          fontWeight: FontWeight.bold,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            print('Terms tapped');
                          },
                      ),
                      const TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: const TextStyle(
                          color: AppColors.secondaryBlue,
                          fontWeight: FontWeight.bold,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            print('Privacy tapped');
                          },
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                /// Continue Button
                ElevatedButton(
                  onPressed: isFormValid
                      ? () async {
                          ref.read(isLoadingProvider.notifier).state = true;

                          await authService.sendOTP(
                            ref: ref,
                            phoneNumber: mobile,
                            onCodeSent: () {
                              ref.read(isLoadingProvider.notifier).state =
                                  false;
                              showDialog(
                                context: context,
                                builder: (context) => OTPDialog(ref: ref),
                              );
                            },
                            onError: (error) {
                              ref.read(isLoadingProvider.notifier).state =
                                  false;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(error),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            },
                          );
                        }
                      : null,

                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFormValid
                        ? AppColors.success
                        : Colors.grey,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: isFormValid ? 3 : 0,
                  ),
                  child: ref.watch(isLoadingProvider)
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Next',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OTPDialog extends StatefulWidget {
  final WidgetRef ref;
  const OTPDialog({super.key, required this.ref});

  @override
  State<OTPDialog> createState() => _OTPDialogState();
}

class _OTPDialogState extends State<OTPDialog> {
  final List<TextEditingController> otpControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );

  final List<FocusNode> focusNodes = List.generate(4, (_) => FocusNode());

  void _submitOTP() async {
    final otp = otpControllers.map((c) => c.text).join();
    if (otp.length == 4) { // now checking 4 digits
      try {
        final mobileNo = widget.ref.read(mobileProvider);
        final profileRepo = ProfileRepository();

        final userExists = await authService.verifyOTPAndCheckUser(
          ref: widget.ref,
          otp: otp, // OTP check done locally
          username: "", // Not needed for API check now
          mobileNo: mobileNo, // Only this is sent to API
          profileRepo: profileRepo,
        );

        Navigator.pop(context); // close OTP dialog

        if (userExists) {
          context.go('/profile');
        } else {
          context.go('/home');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Center(
        child: Text('Enter OTP', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      content: SizedBox(
        height: 160,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (index) {
                return SizedBox(
                  width: 48,
                  height: 56,
                  child: TextField(
                    controller: otpControllers[index],
                    focusNode: focusNodes[index],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: Colors.deepPurple.shade50,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.deepPurple),
                      ),
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty && index < 3) {
                        FocusScope.of(context).requestFocus(focusNodes[index + 1]);
                      } else if (value.isEmpty && index > 0) {
                        FocusScope.of(context).requestFocus(focusNodes[index - 1]);
                      } else if (index == 3 && value.isNotEmpty) {
                        _submitOTP();
                      }
                    },
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            const Text(
              "Enter the 4-digit OTP sent to your number.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
