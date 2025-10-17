import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsKeys {
  static const String driverStatus = "driverStatus";
  static const String riderId = "riderId";
  static const String userId = "userid";
  static const String driverTimer = "driverTimer";
  static const String lastBookingId = "lastBookingId";
  static const String ongoingTrip = "ongoingTrip";
  static const String mobileno = "mobileno";
  static const String driverName = "driverName";
  static const String driverCity = "driverCity";
  static const String isProfileCompleted = "isProfileCompleted";
  static const String fcmToken = "fcmToken";
  static const String driverUsername = "driverUsername";
}

class SharedPrefsHelper {

  /// ---------- SET METHODS ----------
  static Future<void> setDriverStatus(String status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SharedPrefsKeys.driverStatus, status);
  }

  static Future<void> setRiderId(String riderId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SharedPrefsKeys.riderId, riderId);
  }

  static Future<void> setLastBookingId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SharedPrefsKeys.lastBookingId, id);
  }

  static Future<void> setDriverTimer(int driverTimer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(SharedPrefsKeys.driverTimer, driverTimer);
  }

  static Future<void> setUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SharedPrefsKeys.userId, userId);
  }

  static Future<void> setOngoingTrip(String tripJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SharedPrefsKeys.ongoingTrip, tripJson);
  }

  static Future<void> setMobileNo(String mobile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SharedPrefsKeys.mobileno, mobile);
  }

  static Future<void> setDriverName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SharedPrefsKeys.driverName, name);
  }

  static Future<void> setDriverCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SharedPrefsKeys.driverCity, city);
  }

  static Future<void> setFcmToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SharedPrefsKeys.fcmToken, token);
  }

  static Future<void> setProfileCompleted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SharedPrefsKeys.isProfileCompleted, value);
  }

  static Future<void> setDriverUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SharedPrefsKeys.driverUsername, username);
  }

  /// ---------- GET METHODS ----------
  static Future<String> getDriverStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(SharedPrefsKeys.driverStatus) ?? "OF";
  }

  static Future<String> getRiderId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(SharedPrefsKeys.riderId) ?? "";
  }

  static Future<String?> getLastBookingId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(SharedPrefsKeys.lastBookingId);
  }

  static Future<String> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(SharedPrefsKeys.userId) ?? "";
  }

  static Future<String?> getOngoingTrip() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(SharedPrefsKeys.ongoingTrip);
  }

  static Future<String> getMobileNo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(SharedPrefsKeys.mobileno) ?? "";
  }

  static Future<String> getDriverName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(SharedPrefsKeys.driverName) ?? "";
  }

  static Future<String> getDriverCity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(SharedPrefsKeys.driverCity) ?? "";
  }

  static Future<String> getFcmToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(SharedPrefsKeys.fcmToken) ?? "";
  }

  static Future<int> getDriverTimer() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(SharedPrefsKeys.driverTimer) ?? 0;
  }

  static Future<bool> getDriverProfileCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(SharedPrefsKeys.isProfileCompleted) ?? false;
  }

  /// ---------- CLEAR METHODS ----------
  static Future<void> clearDriverStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(SharedPrefsKeys.driverStatus);
  }

  static Future<void> clearOngoingTrip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(SharedPrefsKeys.ongoingTrip);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<void> clearUserId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(SharedPrefsKeys.userId);
  }

  static Future<void> clearLastBookingId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(SharedPrefsKeys.lastBookingId);
  }

  static Future<void> clearRiderId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(SharedPrefsKeys.riderId);
  }
}
