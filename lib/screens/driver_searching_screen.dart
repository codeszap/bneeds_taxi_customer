import 'dart:async';

import 'package:bneeds_taxi_customer/repositories/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/location_provider.dart';
import '../providers/ride_otp_provider.dart';
import 'tracking_screen.dart';
import 'confirm_ride_screen.dart';
import '../providers/trip_status_provider.dart';
import '../utils/sharedPrefrencesHelper.dart';
import '../providers/booking_provider.dart';
import '../widgets/common_shimmer.dart';

// ------------------- ENUM + STATE + PROVIDER -------------------

enum DriverSearchStatus { idle, searching, found, error }

class DriverSearchState {
  final DriverSearchStatus status;
  const DriverSearchState({required this.status});
}

class DriverSearchNotifier extends StateNotifier<DriverSearchState> {
  DriverSearchNotifier(this.ref)
    : super(const DriverSearchState(status: DriverSearchStatus.idle));

  final Ref ref;

  void startSearch() {
    state = const DriverSearchState(status: DriverSearchStatus.searching);
  }

  void markDriverFound() {
    state = const DriverSearchState(status: DriverSearchStatus.found);
  }

  void setError() {
    state = const DriverSearchState(status: DriverSearchStatus.error);
  }

  void cancelSearch() {
    state = const DriverSearchState(status: DriverSearchStatus.idle);
  }

  void clearTripData() {
    ref.invalidate(selectedServiceProvider);
    ref.invalidate(toLocationProvider);
    ref.invalidate(toLatLngProvider);
    ref.invalidate(placeQueryProvider);
    ref.invalidate(rideOtpProvider);
    ref.invalidate(driverLatLongProvider);
    ref.invalidate(driverMobNoProvider);
    ref.invalidate(dropLatLngProvider);
    ref.invalidate(tripStartedProvider);
    ref.invalidate(selectedPaymentProvider);
    ref.invalidate(dateTimeCheckboxProvider);
    ref.invalidate(selectedDateProvider);
    ref.invalidate(selectedTimeProvider);
  }
}

final driverSearchProvider =
    StateNotifierProvider<DriverSearchNotifier, DriverSearchState>(
      (ref) => DriverSearchNotifier(ref),
    );

// ------------------- MAIN SCREEN -------------------

class DriverSearchingScreen extends ConsumerStatefulWidget {
  const DriverSearchingScreen({super.key});

  @override
  ConsumerState<DriverSearchingScreen> createState() =>
      _DriverSearchingScreenState();
}

class _DriverSearchingScreenState extends ConsumerState<DriverSearchingScreen> {
  bool _triggered = false;
  Timer? _searchTimer;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(driverSearchProvider.notifier).startSearch();
      startTimer();
      startPolling();
    });
  }

  void startTimer() {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(minutes: 1), () {
      if (mounted &&
          ref.read(driverSearchProvider).status ==
              DriverSearchStatus.searching) {
        ref.read(driverSearchProvider.notifier).setError();
      }
    });
  }

  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final searchStatus = ref.read(driverSearchProvider).status;
      if (searchStatus != DriverSearchStatus.searching) {
        timer.cancel();
        return;
      }

      final bookingIdStr = await SharedPrefsHelper.getLastBookingId();
      if (bookingIdStr == null || bookingIdStr.isEmpty) return;

      final bookingId = int.tryParse(bookingIdStr);
      if (bookingId == null) return;

      final repository = ref.read(bookingRepositoryProvider);
      final bookingDetail = await repository.checkBookingStatus(bookingId);

      if (bookingDetail != null && mounted) {
        print(
          "🚕 Driver assigned (via polling)! RiderId: ${bookingDetail.riderId}",
        );

        // Save status and details
        await SharedPrefsHelper.setRiderId(bookingDetail.riderId);
        await SharedPrefsHelper.setBookingId(bookingDetail.bookingId);

        // Mark found to trigger navigation in build()
        ref.read(driverSearchProvider.notifier).markDriverFound();
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(driverSearchProvider);
    final notifier = ref.read(driverSearchProvider.notifier);

    if (state.status == DriverSearchStatus.found) {
      _searchTimer?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final tpNotifier = ref.read(tripStatusProvider.notifier);
        await tpNotifier.updateSearching(false);
        await tpNotifier.updateAccepted(true);
        if (mounted) context.go('/tracking');
      });
    }

    return Scaffold(
      backgroundColor: Colors.deepPurple.shade50,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: switch (state.status) {
            DriverSearchStatus.searching => _buildSearchingUI(
              context,
              notifier,
            ),
            DriverSearchStatus.error => _buildErrorUI(context, notifier),
            _ => _buildSearchingUI(context, notifier),
          },
        ),
      ),
    );
  }

  Widget _buildSearchingUI(
    BuildContext context,
    DriverSearchNotifier notifier,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          height: 150,
          width: 150,
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.deepPurple.shade100,
          ),
          child: const CircularProgressIndicator(
            strokeWidth: 6,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
          ),
        ),
        const SizedBox(height: 30),
        const Text(
          "Searching for nearby drivers...",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        const Text(
          "Please wait while we find your best driver",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(height: 40),
        ElevatedButton.icon(
          onPressed: () async {
            await ref.read(tripStatusProvider.notifier).updateSearching(false);
            notifier.clearTripData();
            notifier.cancelSearch();
            _searchTimer?.cancel();
            if (context.mounted) context.go('/home');
          },
          icon: const Icon(Icons.close),
          label: const Text("Cancel Ride"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorUI(BuildContext context, DriverSearchNotifier notifier) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 80),
        const SizedBox(height: 20),

        const Text(
          "Thank you for booking! Our driver will contact you shortly. Please stay patient.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),

        const SizedBox(height: 20),

        // const Text(
        //   "But your ride has been successfully booked.\nA driver will be assigned shortly. Have a pleasant journey!",
        //   textAlign: TextAlign.center,
        //   style: TextStyle(fontSize: 14, color: Colors.black54),
        // ),

        // const SizedBox(height: 30),
        ElevatedButton(
          onPressed: () async {
            await ref.read(tripStatusProvider.notifier).updateSearching(false);
            notifier.clearTripData();
            notifier.cancelSearch();
            if (context.mounted) context.go('/home');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: const Text("Go Home"),
        ),
      ],
    );
  }
}
