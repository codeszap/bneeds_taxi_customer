import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/RideStorage.dart';
import '../providers/ride_otp_provider.dart';
import '../providers/location_provider.dart';
import '../providers/ride_otp_provider.dart';
import '../providers/ride_otp_provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/ride_otp_provider.dart';
import 'tracking_screen.dart';

class ManualStartScreen extends ConsumerWidget {
  const ManualStartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manual Ride Start")),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final container = ref;

            // 1️⃣ Set OTP manually
            container.read(rideOtpProvider.notifier).state = "1234";
            await RideStorage.saveRideOtp("1234");

            // 2️⃣ Set driver location manually
            const driverLatLong = "9.9155706,78.1106788";
            container.read(driverLatLongProvider.notifier).state = driverLatLong;
            await RideStorage.saveDriverLatLong(driverLatLong);

            // 3️⃣ Set driver mobile manually
            const driverMobno = "8870602962";
            container.read(driverMobNoProvider.notifier).state = driverMobno;
            await RideStorage.saveDriverMobNo(driverMobno);

            // 4️⃣ Set drop location manually
            const dropLatLong = "9.920000,78.120000";
            container.read(dropLatLngProvider.notifier).state = dropLatLong;
            await RideStorage.saveDropLatLong(dropLatLong);

            // 5️⃣ Mark trip as started
            container.read(tripStartedProvider.notifier).state = true;
            await RideStorage.saveTripStarted(true);

            // 6️⃣ Navigate to TrackingScreen
            GoRouter.of(context).go('/tracking');
          },
          child: const Text("Start Ride Manually"),
        ),
      ),
    );
  }
}
