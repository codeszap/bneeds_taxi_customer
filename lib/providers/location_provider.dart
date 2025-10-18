
import 'dart:convert';

import 'package:bneeds_taxi_customer/models/location_data.dart';
import 'package:bneeds_taxi_customer/screens/select_location_screen.dart';
import 'package:bneeds_taxi_customer/utils/constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../screens/home/HomeScreen.dart';


// Recent locations
final recentLocationsProvider =
    StateNotifierProvider<RecentLocationsNotifier, List<Map<String, String>>>(
      (ref) => RecentLocationsNotifier(),
    );
// ---- Google Suggestions Provider ----
final placeSuggestionsProvider =
FutureProvider.family<List<PlaceSuggestion>, String>((ref, query) async {
  if (query.isEmpty) return [];

  final url = Uri.parse(
    "https://maps.googleapis.com/maps/api/place/autocomplete/json"
        "?input=$query"
        "&key=${Strings.googleApiKey}"
        "&components=country:IN",
  );

  final response = await http.get(url);
  final data = jsonDecode(response.body);

  if (data["status"] == "OK") {
    final predictions = data["predictions"] as List;
    return predictions
        .map((p) => PlaceSuggestion.fromJson(p))
        .toList();
  }

  return [];
});


final locationErrorDialogShownProvider = StateProvider<bool>((ref) => false);
final selectedServiceProvider = StateProvider<Map<String, dynamic>?>((ref) => null);

final fromLocationProvider = StateProvider<String>((ref) => 'Current Locations');
final toLocationProvider = StateProvider<String>((ref) => '');
final placeQueryProvider = StateProvider<String>((ref) => '');

final fromLatLngProvider = StateProvider<Position?>((ref) => null);
final toLatLngProvider = StateProvider<Position?>((ref) => null);
 

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

Future<Position?> getLatLngFromAddress(String placeId) async {
  final url = Uri.parse(
    "https://maps.googleapis.com/maps/api/place/details/json"
        "?place_id=$placeId"
        "&key=${Strings.googleApiKey}",
  );

  final response = await http.get(url);
  final data = jsonDecode(response.body);

  if (data["status"] == "OK") {
    final location = data["result"]["geometry"]["location"];
    return Position(
      latitude: location["lat"],
      longitude: location["lng"],
      timestamp: DateTime.now(),
      accuracy: 0.0,
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
    );
  }
  return null;
}

