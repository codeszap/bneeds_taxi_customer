// lib/utils/fcmHelper.dart

import 'package:bneeds_taxi_customer/repositories/profile_repository.dart';
import 'package:bneeds_taxi_customer/services/FirebasePushService.dart';
import 'package:bneeds_taxi_customer/utils/sharedPrefrencesHelper.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class FcmHelper {
  /// A centralized function to sync the FCM token with the server.
  /// Call this on app start (Splash) and after a successful login.
  static Future<void> syncTokenWithServer() async {
    try {
      final userId = await SharedPrefsHelper.getUserId();
      final mobileNo = await SharedPrefsHelper.getMobileNo();
      if (mobileNo.isEmpty) {
        debugPrint("FCM Sync: User not logged in. Skipping sync.");
        return; // பயனர் உள்நுழையவில்லை என்றால், இங்கேயே நிறுத்திவிடவும்
      }
      final String? newFcmToken = await FirebaseMessaging.instance
          .getToken();

      if (newFcmToken == null || newFcmToken.isEmpty) {
        debugPrint("FCM Sync: Failed to get a valid token from Firebase.");
        return;
      }

      // 3. ஏற்கனவே மொபைலில் சேமிக்கப்பட்ட பழைய டோக்கனை எடுக்கவும்
      final String? oldFcmToken = await SharedPrefsHelper.getFcmToken();

      // 4. டோக்கன் மாறியிருந்தால் அல்லது இதுவே முதல் முறை என்றால் மட்டும் சர்வரில் புதுப்பிக்கவும்
      if (newFcmToken != oldFcmToken) {
        debugPrint("FCM token has changed. Syncing with server...");

        // உங்கள் Repository-ஐ அழைத்து, சர்வரில் டோக்கனைப் புதுப்பிக்கவும்
        final success = await ProfileRepository().updateFcmToken(
          mobileNo: mobileNo,
          tokenKey: newFcmToken,
        );

        if (success != null) {
          await SharedPrefsHelper.setFcmToken(newFcmToken);
          debugPrint(
            "✅ FCM token synced successfully to server and local storage.",
          );
        } else {
          debugPrint("❌ FCM Sync: Failed to update token on the server.");
        }
      } else {
        debugPrint("ℹ️ FCM token is already up-to-date. No sync needed.");
      }
    } catch (e) {
      debugPrint("🚨 An error occurred during FCM token sync: $e");
    }
  }
}
