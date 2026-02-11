import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bneeds_taxi_customer/repositories/profile_repository.dart';

import '../utils/sharedPrefrencesHelper.dart';

final generatedOtpProvider = StateProvider<String?>((ref) => null);

Future<void> sendOTP({
  required WidgetRef ref,
  required String phoneNumber,
  required Function onCodeSent,
  required Function(String error) onError,
}) async {
  try {
    // -----------------------------------------------------
    // 🍎 CHECK FOR GOOGLE / APPLE REVIEWER BYPASS
    // -----------------------------------------------------
    if (phoneNumber == '9876543210') {
      print("🚀 Reviewer Login Bypass: Sending OTP 1234");
      ref.read(generatedOtpProvider.notifier).state = '1234';
      onCodeSent();
      return;
    }

    // 1. Generate a random 4-digit OTP
    final otp = (Random().nextInt(9000) + 1000).toString(); // 1000–9999

    // 2. Store OTP locally for later verification
    ref.read(generatedOtpProvider.notifier).state = otp;

    // 3. Prepare message
    final message = "microotp~$otp";

    // 4. Build URL for SMS API
    const String proxy = "https://api.allorigins.win/raw?url=";
    final targetUrl =
        "https://nminfotech.in/smsautosend.aspx"
        "?id=RAMMTR"
        "&PWD=RAMMTR"
        "&mob=$phoneNumber"
        "&msg=$message"
        "&tm=T";

    // Use proxy only on Web, otherwise call directly
    final finalUrl = kIsWeb
        ? (proxy + Uri.encodeComponent(targetUrl))
        : targetUrl;
    final url = Uri.parse(finalUrl);

    // Print URL in console for debugging
    print("OTP URL: $url");

    // 5. Send OTP via SMS API
    final response = await http.get(url);

    if (response.statusCode == 200) {
      onCodeSent();
    } else {
      onError("Failed to send OTP: ${response.body}");
    }
  } catch (e) {
    onError("Error sending OTP: ${e.toString()}");
  }
}

/// Returns true if user exists, false if new user
// Future<bool> verifyOTPAndCheckUser({
//   required WidgetRef ref,
//   required String otp,
//   required String username, // unused
//   required String mobileNo,
//   required ProfileRepository profileRepo,
// }) async {
//   final generatedOtp = ref.read(generatedOtpProvider);

//   if (generatedOtp == null) {
//     throw Exception("No OTP generated");
//   }

//   if (otp != generatedOtp) {
//     throw Exception("Invalid OTP");
//   }

//   // Fetch user profile from API
//   final profiles = await profileRepo.fetchUserProfile(mobileno: mobileNo);
//   print("Fetched profiles: ${profiles.map((p) => p.toJson()).toList()}");
//   // If API returned empty list, user does not exist
//   return profiles.isNotEmpty;
// }

Future<bool> verifyOTPAndCheckUser({
  required WidgetRef ref,
  required String otp,
  required String username, // unused
  required String mobileNo,
  required ProfileRepository profileRepo,
}) async {
  // -----------------------------------------------------
  // 🍎 CHECK FOR GOOGLE / APPLE REVIEWER BYPASS
  // -----------------------------------------------------
  if (mobileNo == '9876543210' && otp == '1234') {
    print("🚀 Reviewer Login Bypass: Verification Success");
    // Simulate finding an existing user "9999"
    await SharedPrefsHelper.setUserId("9999");
    await SharedPrefsHelper.setProfileCompleted(true);
    return true;
  }

  final generatedOtp = ref.read(generatedOtpProvider);

  if (generatedOtp == null) {
    throw Exception("No OTP generated");
  }

  if (otp != generatedOtp) {
    throw Exception("Invalid OTP");
  }

  // Fetch user profile from API
  final profiles = await profileRepo.fetchUserProfile(mobileno: mobileNo);
  print("Fetched profiles: ${profiles.map((p) => p.toJson()).toList()}");

  if (profiles.isNotEmpty) {
    final rawUserId = profiles.first.userid;
    final String userId = rawUserId.toString();

    if (userId.isNotEmpty && userId != "null") {
      await SharedPrefsHelper.setUserId(userId);
      await SharedPrefsHelper.setProfileCompleted(true);
      print("Stored userid in session: $userId");
      return true;
    } else {
      print("Warning: Fetched profile has invalid userid: $userId");
      return false; // Treat as new user if ID is invalid
    }
  } else {
    // User does not exist
    return false;
  }
}
