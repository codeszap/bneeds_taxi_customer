import 'dart:async';

import 'package:bneeds_taxi_customer/config/auth_service.dart' as authService;
import 'package:bneeds_taxi_customer/repositories/profile_repository.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';
import '../widgets/common_textfield.dart';
import '../widgets/common_button.dart';

final usernameProvider = StateProvider<String>((ref) => '');
final mobileProvider = StateProvider<String>((ref) => '');
final isLoadingProvider = StateProvider<bool>((ref) => false);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  @override
  void initState() {
    super.initState();
    _checkLocationEnabled();
  }

  Future<void> _checkLocationEnabled() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled && mounted) {
      _showLocationDialog();
    }
  }

  void _showLocationDialog() {
    showDialog(
      barrierDismissible: false, // ❌ user can't dismiss
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "Location Required",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Please turn on location services to continue using the app.",
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () async {
              await Geolocator.openLocationSettings();
              Navigator.of(context).pop();
              _checkLocationEnabled(); // re-check after returning
            },
            child: const Text(
              "Turn On",
              style: TextStyle(
                color: Colors.deepPurple,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
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

  int _secondsRemaining = 180; // 3 minutes timer
  Timer? _timer;
  bool _showResend = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _secondsRemaining = 180;
    _showResend = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        setState(() {
          _showResend = true;
        });
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    for (var c in otpControllers) {
      c.dispose();
    }
    for (var f in focusNodes) {
      f.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  /// Save mobileno in SharedPreferences
  Future<void> _saveMobileNo(
    String mobileno,
    String username,
    bool isProfileCompleted,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mobileno', mobileno);
    await prefs.setString('username', username);
    await prefs.setBool('isProfileCompleted', isProfileCompleted);
    print(
      "📦 Mobile number saved: $mobileno | ProfileCompleted: $isProfileCompleted",
    );
  }

  void _submitOTP() async {
    final otp = otpControllers.map((c) => c.text).join();
    if (otp.length == 4) {
      try {
        final username = widget.ref.read(usernameProvider);
        final mobileNo = widget.ref.read(mobileProvider);
        final profileRepo = ProfileRepository();

        final userExists = await authService.verifyOTPAndCheckUser(
          ref: widget.ref,
          otp: otp,
          username: username,
          mobileNo: mobileNo,
          profileRepo: profileRepo,
        );

        // ✅ Save with isProfileCompleted
        await _saveMobileNo(mobileNo, username, userExists);

        Navigator.pop(context); // close OTP dialog
        print("User exists: $userExists");

        if (userExists) {
          context.go('/home');
        } else {
          context.go('/profile');
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
    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Center(
        child: Text('Enter OTP', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      content: SizedBox(
        height: 150,
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
                        FocusScope.of(
                          context,
                        ).requestFocus(focusNodes[index + 1]);
                      } else if (value.isEmpty && index > 0) {
                        FocusScope.of(
                          context,
                        ).requestFocus(focusNodes[index - 1]);
                      } else if (index == 3 && value.isNotEmpty) {
                        _submitOTP();
                      }
                    },
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Text(
              "Enter the 4-digit OTP sent to your number.",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            _showResend
                ? TextButton(
                    onPressed: () async {
                      print("🔁 Resend OTP triggered");

                      final mobileNo = widget.ref.read(mobileProvider);

                      // 🔹 API call to resend OTP
                      await authService.sendOTP(
                        ref: widget.ref,
                        phoneNumber: mobileNo,
                        onCodeSent: () {
                          print("✅ OTP resent successfully");
                          _startTimer(); // restart timer after resend
                        },
                        onError: (error) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(error),
                              backgroundColor: Colors.red,
                            ),
                          );
                        },
                      );
                    },
                    child: const Text(
                      "Resend OTP",
                      style: TextStyle(
                        color: Colors.deepPurple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : Text(
                    "Expires in $minutes:$seconds",
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
