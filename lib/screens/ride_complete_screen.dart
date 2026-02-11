import 'package:flutter/material.dart';
import '../models/RideStorage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/location_provider.dart';
import '../providers/ride_otp_provider.dart';
import '../utils/sharedPrefrencesHelper.dart';
import 'tracking_screen.dart'; // Add this to access tripStartedProvider

class RideCompleteScreen extends ConsumerWidget {
  final String fareAmount; // ← add this

  const RideCompleteScreen({super.key, required this.fareAmount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextEditingController reviewController = TextEditingController();
    int rating = 4;

    return Scaffold(
      backgroundColor: Colors.deepPurple.shade50,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const SizedBox(height: 30),

                      // ✅ Success Icon
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 70,
                          color: Colors.green,
                        ),
                      ),

                      const SizedBox(height: 20),
                      const Text(
                        'Trip Completed!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'You have arrived at your destination safely.',
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 30),

                      // 💸 Fare Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.deepPurple.shade300,
                              Colors.deepPurple,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepPurple.shade100,
                              blurRadius: 10,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              "Total Fare",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "₹$fareAmount", // ← dynamic fare
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // ⭐ Rate your trip (same as before)
                      const Text(
                        "Rate your trip",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),

                      StatefulBuilder(
                        builder: (context, setState) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              return IconButton(
                                onPressed: () =>
                                    setState(() => rating = index + 1),
                                icon: Icon(
                                  index < rating
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  color: Colors.amber,
                                  size: 30,
                                ),
                              );
                            }),
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // 📝 Review box
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: reviewController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: "Write a review (optional)",
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(16),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // ✅ Done button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            // 🧹 Clear SharedPreferences & Storage
                            await SharedPrefsHelper.saveTripAccepted(false);
                            await SharedPrefsHelper.clearBookingId();
                            await SharedPrefsHelper.clearRiderId();
                            await SharedPrefsHelper.setIsSearching(false);
                            await SharedPrefsHelper.clearTripCompleted();
                            await SharedPrefsHelper.clearFareAmount();
                            await SharedPrefsHelper.clearTripStarted();
                            await RideStorage.clearRideData();

                            // 🧹 Reset all ride related providers
                            ref.read(fromLocationProvider.notifier).state =
                                'Current Locations';
                            ref.read(toLocationProvider.notifier).state = '';
                            ref.read(fromLatLngProvider.notifier).state = null;
                            ref.read(toLatLngProvider.notifier).state = null;
                            ref.read(selectedServiceProvider.notifier).state =
                                null;

                            // Reset other trip states just in case
                            ref.read(rideOtpProvider.notifier).state = '';
                            ref.read(tripStartedProvider.notifier).state =
                                false;

                            final review = reviewController.text.trim();
                            if (context.mounted) {
                              context.go('/home');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Done',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
