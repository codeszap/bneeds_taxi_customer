import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../widgets/common_textfield.dart';
import '../widgets/common_button.dart';

final usernameProvider = StateProvider<String>((ref) => '');
final mobileProvider = StateProvider<String>((ref) => '');

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final username = ref.watch(usernameProvider);
    final mobile = ref.watch(mobileProvider);

    final isFormValid = username.isNotEmpty && mobile.length == 10;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            CommonTextField(
              label: 'Username',
              keyboardType: TextInputType.text,
              onChanged: (val) => ref.read(usernameProvider.notifier).state = val,
            ),
            const SizedBox(height: 20),
            CommonTextField(
              label: 'Mobile Number',
              keyboardType: TextInputType.phone,
              maxLength: 10,
              onChanged: (val) => ref.read(mobileProvider.notifier).state = val,
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Text.rich(
                TextSpan(
                  text: 'By continuing, you agree to our ',
                  style: const TextStyle(color: Colors.black, fontSize: 12),
                  children: [
                    TextSpan(
                      text: 'Terms of Service',
                      style: const TextStyle(
                        color: AppColors.secondaryBlue,
                        fontWeight: FontWeight.bold,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          print('T&S');
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
                          print('Privacy Policy tapped');
                        },
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
                textAlign: TextAlign.left,
              ),
            ),
            const SizedBox(height: 20),
            CommonButton(
              text: 'Next',
              onPressed: isFormValid ? () {
                context.go('/home');
              } : () {},
              isLoading: false,
              width: double.infinity,
              backgroundColor: isFormValid ? AppColors.success : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
