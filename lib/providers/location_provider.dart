
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

final locationErrorDialogShownProvider = StateProvider<bool>((ref) => false);
final selectedServiceProvider = StateProvider<Map<String, dynamic>?>((ref) => null);

final fromLocationProvider = StateProvider<String>((ref) => 'Current Locations');
final toLocationProvider = StateProvider<String>((ref) => '');
final placeQueryProvider = StateProvider<String>((ref) => '');

final currentLocationProvider = FutureProvider<Position>((ref) async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw Exception('Location services are disabled.');
  }

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      throw Exception('Location permissions are denied.');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    throw Exception('Location permissions are permanently denied.');
  }

  return await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
  );
});
