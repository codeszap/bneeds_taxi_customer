import 'package:shared_preferences/shared_preferences.dart';

class RideStorage {
  static const _keyTripStarted = 'tripStarted';
  static const _keyTripAccepted = 'tripAccepted';
  static const _keyDriverLatLong = 'driverLatLong';
  static const _keyDropLatLong = 'dropLatLong';
  static const _keyDriverMobNo = 'driverMobNo';
  static const _keyRideOtp = 'rideOtp';

  // SAVE
  static Future<void> saveTripStarted(bool started) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTripAccepted, started);
  }

  static Future<void> saveTripAccepted(bool started) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTripStarted, started);
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

  // CLEAR ALL
  static Future<void> clearRideData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyTripStarted);
    await prefs.remove(_keyDriverLatLong);
    await prefs.remove(_keyDropLatLong);
    await prefs.remove(_keyDriverMobNo);
    await prefs.remove(_keyRideOtp);
    await prefs.remove(_keyTripAccepted);
  }
}
