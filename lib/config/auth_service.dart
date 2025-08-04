import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final verificationIdProvider = StateProvider<String?>((ref) => null);

Future<void> sendOTP({
  required WidgetRef ref,
  required String phoneNumber,
  required Function onCodeSent,
  required Function(String error) onError,
}) async {
  await ref.read(firebaseAuthProvider).verifyPhoneNumber(
    phoneNumber: '+91$phoneNumber',
    timeout: const Duration(seconds: 60),
    verificationCompleted: (PhoneAuthCredential credential) {},
    verificationFailed: (FirebaseAuthException e) => onError(e.message ?? "Failed"),
    codeSent: (String verificationId, int? resendToken) {
      ref.read(verificationIdProvider.notifier).state = verificationId;
      onCodeSent();
    },
    codeAutoRetrievalTimeout: (String verificationId) {
      ref.read(verificationIdProvider.notifier).state = verificationId;
    },
  );
}

Future<void> verifyOTP({
  required WidgetRef ref,
  required String otp,
  required Function() onSuccess,
  required Function(String error) onError,
}) async {
  final verificationId = ref.read(verificationIdProvider);
  if (verificationId == null) {
    onError("Verification ID is null");
    return;
  }

  final credential = PhoneAuthProvider.credential(
    verificationId: verificationId,
    smsCode: otp,
  );

  try {
    await ref.read(firebaseAuthProvider).signInWithCredential(credential);
    onSuccess();
  } catch (e) {
    onError("Invalid OTP");
  }
}
