import 'package:shared_preferences/shared_preferences.dart';

class RideStorage {
  static const _keyTripStarted = 'tripStarted';
  static const _keyTripAccepted = 'tripAccepted';
  static const _keyDriverLatLong = 'driverLatLong';
  static const _keyDropLatLong = 'dropLatLong';
  static const _keyDriverMobNo = 'driverMobNo';
  static const _keyRideOtp = 'rideOtp';
  static const _keyTripCompleted = 'tripCompleted';
  static const _keyFareAmount = 'fareAmount';

  // SAVE
  static Future<void> saveTripStarted(bool started) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTripStarted, started);
  }

  static Future<void> saveTripAccepted(bool accepted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTripAccepted, accepted);
  }

  static Future<void> saveDriverLatLong(String latLong) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDriverLatLong, latLong);
  }

  static Future<void> saveDropLatLong(String latLong) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDropLatLong, latLong);
  }

  static Future<void> saveDriverMobNo(String mobNo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDriverMobNo, mobNo);
  }

  static Future<void> saveRideOtp(String otp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRideOtp, otp);
  }

  static Future<void> saveTripCompleted(bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTripCompleted, completed);
  }

  static Future<void> saveFareAmount(String amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFareAmount, amount);
  }

  // LOAD
  static Future<bool> getTripStarted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyTripStarted) ?? false;
  }

  static Future<bool> getTripAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyTripAccepted) ?? false;
  }

  static Future<String?> getDriverLatLong() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDriverLatLong);
  }

  static Future<String?> getDropLatLong() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDropLatLong);
  }

  static Future<String?> getDriverMobNo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDriverMobNo);
  }

  static Future<String?> getRideOtp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRideOtp);
  }

  static Future<bool> getTripCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyTripCompleted) ?? false;
  }

  static Future<String> getFareAmount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFareAmount) ?? "0";
  }

  // CLEAR ALL
  static Future<void> clearRideData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyTripStarted);
    await prefs.remove(_keyDriverLatLong);
    await prefs.remove(_keyDropLatLong);
    await prefs.remove(_keyDriverMobNo);
    await prefs.remove(_keyRideOtp);
    await prefs.remove(_keyTripAccepted);
    await prefs.remove(_keyTripCompleted);
    await prefs.remove(_keyFareAmount);
  }
}
