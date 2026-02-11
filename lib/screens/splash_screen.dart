import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/common_shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart'; // Add this
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/fcmHelper.dart';
import '../utils/sharedPrefrencesHelper.dart';
import '../utils/remote_config_helper.dart'; // Add this
import '../providers/booking_provider.dart';
import '../models/get_booking_model.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  void _showUpdateDialog({required bool isForce}) {
    showDialog(
      context: context,
      barrierDismissible: !isForce,
      builder: (ctx) => PopScope(
        canPop: !isForce, // Disables back button if it's a force update
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "Update Available",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            isForce
                ? "A mandatory update is available. Please update the app to continue using our services."
                : "A new version of the app is available. Update now for better experience.",
          ),
          actions: [
            if (!isForce)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _proceedToSession();
                },
                child: const Text("Later"),
              ),
            ElevatedButton(
              onPressed: () async {
                final Uri playStoreUri = Uri.parse(
                  "https://play.google.com/store/apps/details?id=com.nminfotechsolutions.bneeds_taxi_customer",
                );
                if (await canLaunchUrl(playStoreUri)) {
                  await launchUrl(
                    playStoreUri,
                    mode: LaunchMode.externalApplication,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
              ),
              child: const Text(
                "Update Now",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkSession() async {
    final needsUpdate = await RemoteConfigHelper.shouldUpdate();
    if (needsUpdate) {
      _showUpdateDialog(isForce: RemoteConfigHelper.isForceUpdate);
    } else {
      await _proceedToSession();
    }
  }

  Future<void> _proceedToSession() async {
    final prefs = await SharedPreferences.getInstance();
    final mobileNo = prefs.getString('mobileno');
    final isProfileCompleted = prefs.getBool('isProfileCompleted') ?? false;

    // Delay to show splash for at least 3 seconds
    await Future.delayed(const Duration(seconds: 3));

    // 🔄 Sync state with server if a trip was in progress
    bool currentTripCompleted = await SharedPrefsHelper.getTripCompleted();
    bool currentTripAccepted = await SharedPrefsHelper.getTripAccepted();
    bool currentIsSearching = await SharedPrefsHelper.getIsSearching();
    String currentFareAmount = await SharedPrefsHelper.getFareAmount();

    final String bId = await SharedPrefsHelper.getBookingId();
    final String rId = await SharedPrefsHelper.getRiderId();

    if (bId.isNotEmpty && (currentTripAccepted || currentIsSearching)) {
      try {
        print("🔄 SplashScreen: Syncing trip status for booking $bId...");
        final container = ProviderScope.containerOf(context, listen: false);
        final results = await container.read(bookingRepositoryProvider).fetchBookingDetail(
          int.parse(bId),
          rId.isEmpty ? 0 : int.parse(rId),
        );

        if (results.isNotEmpty) {
          final ride = results.first;
          print("🔄 SplashScreen: Remote status is ${ride.tripStatus}");

          // If completed on server but not locally
          if (ride.tripStatus == 'C' || ride.tripStatus == 'F' || ride.tripStatus == 'Completed') {
            currentTripCompleted = true;
            currentTripAccepted = false;
            currentIsSearching = false;
            
            // Priority: finalAmt > fareAmount
            String fare = ride.fareAmount.toString();
            if (ride.finalAmt != null && ride.finalAmt!.isNotEmpty && ride.finalAmt != "0" && ride.finalAmt != "0.0") {
              fare = ride.finalAmt!;
            }
            currentFareAmount = fare;

            await SharedPrefsHelper.setTripCompleted(true);
            await SharedPrefsHelper.saveTripAccepted(false);
            await SharedPrefsHelper.setIsSearching(false);
            await SharedPrefsHelper.setFareAmount(currentFareAmount);
            await SharedPrefsHelper.saveTripStarted(false);
          } else if (ride.tripStatus == 'X' || ride.tripStatus == 'Cancelled') {
            // If cancelled on server
            currentTripAccepted = false;
            currentIsSearching = false;
            await SharedPrefsHelper.saveTripAccepted(false);
            await SharedPrefsHelper.setIsSearching(false);
          }
        } else {
          // archive/empty case: Ride is gone from active list, assuming it finished.
          if (currentTripAccepted) {
            print("🔄 SplashScreen: Trip gone from active list. Marking as Completed.");
            currentTripCompleted = true;
            currentTripAccepted = false;
            await SharedPrefsHelper.setTripCompleted(true);
            await SharedPrefsHelper.saveTripAccepted(false);
            await SharedPrefsHelper.saveTripStarted(false);
          }
        }
      } catch (e) {
        print("⚠️ SplashScreen: Sync failed: $e");
      }
    }

    final tripAccepted = currentTripAccepted;
    final isSearching = currentIsSearching;
    final tripCompleted = currentTripCompleted;
    final fareAmount = currentFareAmount;

    if (!mounted) return;

    // Direct navigation based on ride state
    if (tripCompleted) {
      context.go('/ride-complete', extra: {'fareAmount': fareAmount});
    } else if (tripAccepted) {
      context.go('/tracking');
    } else if (isSearching) {
      context.go('/searching');
    } else if (mobileNo != null && mobileNo.isNotEmpty) {
      await FcmHelper.syncTokenWithServer();
      if (isProfileCompleted) {
        context.go('/home');
      } else {
        context.go('/profile');
      }
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF123456),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/logo.png', width: 180, height: 180),
              const SizedBox(height: 24),
              const Text(
                "Get there fast, safe and smart.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
              const SizedBox(height: 40),
              const CommonShimmer(
                width: double.infinity,
                height: 6,
                borderRadius: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
