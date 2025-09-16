import 'dart:convert';
import 'package:bneeds_taxi_customer/models/user_profile_model.dart'; // DriverProfile model
import 'package:bneeds_taxi_customer/providers/location_provider.dart';
import 'package:bneeds_taxi_customer/repositories/profile_repository.dart';
import 'package:bneeds_taxi_customer/services/FirebasePushService.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import 'package:bneeds_taxi_customer/models/user_profile_model.dart';
import 'package:bneeds_taxi_customer/providers/location_provider.dart';
import 'package:bneeds_taxi_customer/repositories/profile_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  void markDriverFound() {
    state = DriverSearchState(status: DriverSearchStatus.found);
  }

  Future<void> beginSearch(String vehSubTypeId) async {
    try {
      state = DriverSearchState(status: DriverSearchStatus.loading);

      // Fetch drivers
      drivers = await ProfileRepository().fetchDriverProfile(
        vehSubTypeId: vehSubTypeId,
      );

      if (drivers.isEmpty) {
        state = DriverSearchState(status: DriverSearchStatus.error);
        return;
      }

      state = DriverSearchState(status: DriverSearchStatus.searching);
      await Future.delayed(const Duration(seconds: 2));

      state = DriverSearchState(status: DriverSearchStatus.sending);

      final fromLocation = ref.read(fromLocationProvider);
      final toLocation = ref.read(toLocationProvider);
      final amount =
          double.tryParse(ref.read(selectedServiceProvider)?['price'] ?? '0') ??
          0;
      final prefs = await SharedPreferences.getInstance();
      final fcmToken = await prefs.getString('fcmToken');
      final lastBookingId = await prefs.getString("lastBookingId");

      for (final driver in drivers) {
        if (driver.tokenKey.isNotEmpty) {
          final success = await FirebasePushService.sendPushNotification(
            fcmToken: driver.tokenKey,
            title: "New Ride Request",
            body: "Pickup: $fromLocation\nDrop: $toLocation\nFare: ₹$amount",
            data: {
              "pickup": fromLocation,
              "drop": toLocation,
              "fare": amount.toString(),
              "vehTypeId": ref.read(selectedServiceProvider)?['typeId'],
              "bookingId": lastBookingId,
              "token": fcmToken ?? '',
            },
          );

          print(
            success
                ? "✅ Ride request sent to ${driver.riderName}"
                : "❌ Ride request FAILED for ${driver.riderName}",
          );
        }
      }

      state = DriverSearchState(status: DriverSearchStatus.searching);
    } catch (e) {
      print("❌ Driver search error: $e");
      state = DriverSearchState(status: DriverSearchStatus.error);
    }
  }

  void cancelSearch() {
    state = DriverSearchState(status: DriverSearchStatus.idle);
    drivers = [];
  }
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

              DriverSearchStatus.searching => Column(
                key: const ValueKey('searching'),
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
                  const Icon(Icons.error, color: Colors.red, size: 80),
                  const SizedBox(height: 20),
                  const Text(
                    "Failed to find drivers!",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      notifier.cancelSearch();
                      if (GoRouter.of(context).canPop()) {
                        context.pop();
                      }
                    },
                    child: const Text("Go Back"),
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
