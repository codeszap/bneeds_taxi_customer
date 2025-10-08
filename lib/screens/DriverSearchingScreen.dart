import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:bneeds_taxi_customer/models/user_profile_model.dart'; // DriverProfile model
import 'package:bneeds_taxi_customer/providers/location_provider.dart';
import 'package:bneeds_taxi_customer/repositories/profile_repository.dart';
import 'package:bneeds_taxi_customer/services/FirebasePushService.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DriverSearchStatus { idle, loading, searching, sending, found, error }

class DriverSearchState {
  final DriverSearchStatus status;
  DriverSearchState({required this.status});
}

class DriverSearchNotifier extends StateNotifier<DriverSearchState> {
  DriverSearchNotifier(this.ref)
      : super(DriverSearchState(status: DriverSearchStatus.idle));

  final Ref ref;
  List<DriverProfile> drivers = [];
  bool _isCancelled = false;

  void markDriverFound() {
    state = DriverSearchState(status: DriverSearchStatus.found);
  }

  void cancelSearch() {
    _isCancelled = true;
    state = DriverSearchState(status: DriverSearchStatus.idle);
    drivers = [];
  }

  // Future<void> beginSearch(String vehSubTypeId) async {
  //   try {
  //     state = DriverSearchState(status: DriverSearchStatus.loading);
  //     _isCancelled = false;
  //
  //     // 1️⃣ Fetch online drivers
  //     drivers = await ProfileRepository().getDriverNearby(
  //       vehSubTypeId: vehSubTypeId,
  //       riderStatus: "OL",
  //     );
  //
  //     if (drivers.isEmpty) {
  //       state = DriverSearchState(status: DriverSearchStatus.error);
  //       return;
  //     }
  //
  //     // 2️⃣ Get customer locations
  //     final fromLatLng = ref.read(fromLatLngProvider);
  //     final toLatLng = ref.read(toLatLngProvider);
  //
  //     if (fromLatLng == null || toLatLng == null) {
  //       print("❌ Customer location not set!");
  //       state = DriverSearchState(status: DriverSearchStatus.error);
  //       return;
  //     }
  //
  //     final fromLatLongStr = "${fromLatLng.latitude},${fromLatLng.longitude}";
  //     final toLatLongStr = "${toLatLng.latitude},${toLatLng.longitude}";
  //
  //     final fromLocation = ref.read(fromLocationProvider);
  //     final toLocation = ref.read(toLocationProvider);
  //     final amount = double.tryParse(ref.read(selectedServiceProvider)?['price'] ?? '0') ?? 0;
  //
  //     final prefs = await SharedPreferences.getInstance();
  //     final fcmToken = prefs.getString('fcmToken') ?? '';
  //     final lastBookingId = prefs.getString("lastBookingId") ?? '';
  //     final userId = prefs.getString('userid') ?? '';
  //     final mobileNo = prefs.getString('mobileno') ?? '';
  //
  //     state = DriverSearchState(status: DriverSearchStatus.searching);
  //
  //     // 3️⃣ Send push to all drivers concurrently
  //     final futures = drivers.map((driver) async {
  //       if (_isCancelled || driver.tokenKey.isEmpty) return false;
  //
  //       state = DriverSearchState(status: DriverSearchStatus.sending);
  //
  //       final success = await FirebasePushService.sendPushNotification(
  //         fcmToken: driver.tokenKey,
  //         title: "New Ride Request",
  //         body: "Pickup: $fromLocation\nDrop: $toLocation\nFare: ₹$amount",
  //         data: {
  //           "pickuplatlong": fromLatLongStr,       // driver expects "lat,lng"
  //           "droplatlong": toLatLongStr,           // driver expects "lat,lng"
  //           "pickup": fromLocation.toString(),
  //           "drop": toLocation.toString(),
  //           "fare": amount.toString(),
  //           "vehTypeId": ref.read(selectedServiceProvider)?['typeId'] ?? '',
  //           "bookingId": lastBookingId,
  //           "token": fcmToken,
  //           "userId": userId,
  //           "userMobNo": mobileNo,
  //         },
  //       );
  //
  //       print(
  //         success
  //             ? "✅ Ride request sent to ${driver.riderName}"
  //             : "❌ Ride request FAILED for ${driver.riderName}",
  //       );
  //
  //       // Wait 30s for driver to accept
  //       final accepted = await _waitForDriverResponse(const Duration(seconds: 30));
  //       return accepted;
  //     }).toList();
  //
  //     // 4️⃣ Check if any driver accepted
  //     final results = await Future.wait(futures);
  //     if (results.any((accepted) => accepted)) {
  //       markDriverFound();
  //     } else if (!_isCancelled) {
  //       state = DriverSearchState(status: DriverSearchStatus.error);
  //     }
  //
  //   } catch (e) {
  //     print("❌ Driver search error: $e");
  //     state = DriverSearchState(status: DriverSearchStatus.error);
  //   }
  // }


  Future<void> beginSearch(String vehSubTypeId) async {
    try {
      state = DriverSearchState(status: DriverSearchStatus.loading);
      _isCancelled = false;

      // 1️⃣ Fetch online drivers
      drivers = await ProfileRepository().getDriverNearby(
        vehSubTypeId: vehSubTypeId,
        riderStatus: "OL",
      );

      if (drivers.isEmpty) {
        state = DriverSearchState(status: DriverSearchStatus.error);
        return;
      }

      final fromLatLng = ref.read(fromLatLngProvider);
      final toLatLng = ref.read(toLatLngProvider);
      if (fromLatLng == null || toLatLng == null) {
        state = DriverSearchState(status: DriverSearchStatus.error);
        return;
      }

      final fromLatLongStr = "${fromLatLng.latitude},${fromLatLng.longitude}";
      final toLatLongStr = "${toLatLng.latitude},${toLatLng.longitude}";
      final fromLocation = ref.read(fromLocationProvider);
      final toLocation = ref.read(toLocationProvider);
      final amount = double.tryParse(ref.read(selectedServiceProvider)?['price'] ?? '0') ?? 0;

      final prefs = await SharedPreferences.getInstance();
      final fcmToken = prefs.getString('fcmToken') ?? '';
      final lastBookingId = prefs.getString("lastBookingId") ?? '';
      final userId = prefs.getString('userid') ?? '';
      final mobileNo = prefs.getString('mobileno') ?? '';

      state = DriverSearchState(status: DriverSearchStatus.sending);

      // 2️⃣ Send push to all drivers in parallel
      for (var driver in drivers) {
        if (driver.tokenKey.isNotEmpty) {
          FirebasePushService.sendPushNotification(
            fcmToken: driver.tokenKey,
            title: "New Ride Request",
            body: "Pickup: $fromLocation\nDrop: $toLocation\nFare: ₹$amount",
            data: {
              "pickuplatlong": fromLatLongStr,
              "droplatlong": toLatLongStr,
              "pickup": fromLocation.toString(),
              "drop": toLocation.toString(),
              "fare": amount.toString(),
              "vehTypeId": ref.read(selectedServiceProvider)?['typeId'] ?? '',
              "bookingId": lastBookingId,
              "token": fcmToken,
              "userId": userId,
              "userMobNo": mobileNo,
              "duration" : "30",
            },
          );
        }
      }

      // 3️⃣ Wait for max 30 seconds globally
      final accepted = await _waitForAnyDriverResponse(const Duration(seconds: 40));

      if (accepted) {
        markDriverFound();
      } else if (!_isCancelled) {
        state = DriverSearchState(status: DriverSearchStatus.error);
      }
    } catch (e) {
      state = DriverSearchState(status: DriverSearchStatus.error);
      print("❌ Driver search error: $e");
    }
  }

// Global wait function
  Future<bool> _waitForAnyDriverResponse(Duration timeout) async {
    int elapsed = 0;
    const interval = 1;

    while (elapsed < timeout.inSeconds) {
      await Future.delayed(Duration(seconds: interval));
      elapsed += interval;

      if (state.status == DriverSearchStatus.found) return true;
      if (_isCancelled) return false;
    }

    return false; // timeout
  }





// Utility functions
  List<double> parseLatLong(String latlong) {
    final parts = latlong.split(',');
    if (parts.length != 2) return [0, 0];
    return [
      double.tryParse(parts[0].trim()) ?? 0,
      double.tryParse(parts[1].trim()) ?? 0,
    ];
  }

  double calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // km
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat/2) * sin(dLat/2) +
        cos(lat1 * pi/180) * cos(lat2 * pi/180) *
            sin(dLon/2) * sin(dLon/2);
    final c = 2 * atan2(sqrt(a), sqrt(1-a));
    return R * c;
  }


  // Future<void> beginSearch(String vehSubTypeId) async {
  //   try {
  //     state = DriverSearchState(status: DriverSearchStatus.loading);
  //     _isCancelled = false;
  //
  //     // Get ride details
  //     final fromLocation = ref.read(fromLocationProvider);
  //     final toLocation = ref.read(toLocationProvider);
  //     final fromlatlong = ref.read(fromLatLngProvider);
  //     final tolatlong = ref.read(toLatLngProvider);
  //     final amount =
  //         double.tryParse(ref.read(selectedServiceProvider)?['price'] ?? '0') ?? 0;
  //
  //     final prefs = await SharedPreferences.getInstance();
  //     final fcmToken = prefs.getString('fcmToken');
  //     final lastBookingId = prefs.getString("lastBookingId");
  //     final userId = prefs.getString('userid') ?? "";
  //     final mobileNo = prefs.getString('mobileno') ?? "";
  //
  //     // 🔹 Hardcoded driver FCM token (your test driver)
  //     const testDriverToken =
  //         "ez9fo1r4SOCjFvp3fsy39a:APA91bH3osk0zWziH8wnN0OF_fghWayxWlLdqwudnUkt87Fp3K9chpF4_sBC_4ZlMZJRhyU6UDocpFDanNmqrJca76FbU4RVM-n4jnCatqHqVj6L9LTP7Xg";
  //
  //     if (_isCancelled) return;
  //
  //     state = DriverSearchState(status: DriverSearchStatus.sending);
  //
  //     final success = await FirebasePushService.sendPushNotification(
  //       fcmToken: testDriverToken,
  //       title: "New Ride Request",
  //       body: "Pickup: $fromLocation\nDrop: $toLocation\nFare: ₹$amount",
  //       data: {
  //         "pickuplatlong": fromlatlong.toString(),
  //         "droplatlong": tolatlong.toString(),
  //         "pickup": fromLocation.toString(),
  //         "drop": toLocation.toString(),
  //         "fare": amount.toString(),
  //         "vehTypeId": ref.read(selectedServiceProvider)?['typeId'],
  //         "bookingId": lastBookingId,
  //         "token": fcmToken ?? '',
  //         "userId": userId,
  //         "userMobNo": mobileNo,
  //       },
  //     );
  //
  //     print(success
  //         ? "✅ Ride request sent to TEST DRIVER"
  //         : "❌ Ride request FAILED to TEST DRIVER");
  //
  //     // Wait max 5 sec for driver accept
  //     final accepted = await _waitForDriverResponse(const Duration(seconds: 5));
  //     if (accepted) {
  //       markDriverFound();
  //       return;
  //     }
  //
  //     if (!_isCancelled) {
  //       state = DriverSearchState(status: DriverSearchStatus.error);
  //     }
  //   } catch (e) {
  //     print("❌ Driver search error: $e");
  //     state = DriverSearchState(status: DriverSearchStatus.error);
  //   }
  // }
  //

  // Future<bool> _waitForDriverResponse(Duration timeout) async {
  //   // Polling approach: check every second if driver accepted
  //   int elapsed = 0;
  //   const interval = 1;
  //
  //   while (elapsed < timeout.inSeconds) {
  //     await Future.delayed(Duration(seconds: interval));
  //     elapsed += interval;
  //
  //     if (state.status == DriverSearchStatus.found) return true;
  //     if (_isCancelled) return false;
  //   }
  //
  //   return false; // timeout
  // }
}

// Provider
final driverSearchProvider =
StateNotifierProvider.autoDispose<DriverSearchNotifier, DriverSearchState>(
      (ref) => DriverSearchNotifier(ref),
);

// Screen
class DriverSearchingScreen extends ConsumerStatefulWidget {
  const DriverSearchingScreen({super.key});

  @override
  ConsumerState<DriverSearchingScreen> createState() =>
      _DriverSearchingScreenState();
}

class _DriverSearchingScreenState extends ConsumerState<DriverSearchingScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final selected = ref.read(selectedServiceProvider);
      final vehSubTypeId = selected?['typeId']?.toString() ?? "0";
      ref.read(driverSearchProvider.notifier).beginSearch(vehSubTypeId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(driverSearchProvider);
    final notifier = ref.read(driverSearchProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.deepPurple.shade50,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: switch (state.status) {
              DriverSearchStatus.loading => Column(
                key: const ValueKey('loading'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(color: Colors.deepPurple),
                  SizedBox(height: 20),
                  Text(
                    "Preparing your ride...",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),

              DriverSearchStatus.sending => Column(
                key: const ValueKey('sending'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 160,
                    width: 160,
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.deepPurple.shade100,
                    ),
                    child: const CircularProgressIndicator(
                      strokeWidth: 6,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.deepPurple,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    "Searching for nearby drivers...",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Hang tight! Finding your best driver...",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    onPressed: () {
                      notifier.cancelSearch();
                      if (GoRouter.of(context).canPop()) {
                        context.pop();
                      }
                      context.go("/home");
                    },
                    icon: const Icon(Icons.close),
                    label: const Text("Cancel Ride"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),

              DriverSearchStatus.sending => Column(
                key: const ValueKey('sending'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(color: Colors.orange),
                  SizedBox(height: 20),
                  Text(
                    "Sending ride requests to drivers...",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),

              DriverSearchStatus.found => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(color: Colors.deepPurple),
                  SizedBox(height: 20),
                  Text(
                    "Waiting for a driver to accept your ride...",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Drivers have been notified. Hang tight!",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),

              DriverSearchStatus.error => Column(
                key: const ValueKey('error'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.car_rental_outlined,
                          color: Colors.redAccent,
                          size: 80,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "No drivers available nearby",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Please try again later or change your pickup location.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      notifier.cancelSearch();
                      context.go("/home");
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text("Go Home"),
                  ),

                ],
              ),

              _ => const SizedBox.shrink(),
            },
          ),
        ),
      ),
    );
  }
}
