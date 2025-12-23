import 'package:bneeds_taxi_customer/providers/location_provider.dart';
import 'package:bneeds_taxi_customer/repositories/booking_repository.dart';
import 'package:bneeds_taxi_customer/models/booking_model.dart';
import 'package:bneeds_taxi_customer/widgets/common_main_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/sharedPrefrencesHelper.dart';

// Payment selection provider
final selectedPaymentProvider = StateProvider<String>((ref) => "Cash");
final dateTimeCheckboxProvider = StateProvider<bool>((ref) => false);

// Booking repository provider
final bookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => BookingRepository(),
);

// Date & Time pickers providers
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());
final selectedTimeProvider = StateProvider<TimeOfDay>((ref) => TimeOfDay.now());

class ConfirmRideScreen extends ConsumerWidget {
  const ConfirmRideScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedServiceProvider);
    final fromPos = ref.read(fromLatLngProvider);
    final toPos = ref.read(toLatLngProvider);
    final pickupLocation = ref.watch(fromLocationProvider);
    final dropLocation = ref.watch(toLocationProvider);

    bool isBooking = false;

    final pickupAddress = pickupLocation.isNotEmpty
        ? pickupLocation
        : "Not selected";
    final dropAddress = dropLocation.isNotEmpty ? dropLocation : "Not selected";

    if (selected == null) {
      return const Scaffold(body: Center(child: Text("No service selected")));
    }

    String formatTime12Hour(TimeOfDay time) {
      final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
      final minute = time.minute.toString().padLeft(2, '0');
      final ampm = time.period == DayPeriod.am ? "AM" : "PM";
      return "$hour:$minute $ampm";
    }

    Future<void> confirmBooking(BuildContext context, WidgetRef ref) async {
      bool isBooking = false;

      if (isBooking) return;
      isBooking = true;

      final repository = ref.read(bookingRepositoryProvider);
      final userId = SharedPrefsHelper.getUserId();
      final mobileNo = SharedPrefsHelper.getMobileNo();

      final selectedDate = ref.read(selectedDateProvider);
      final selectedTime = ref.read(selectedTimeProvider);
      final isScheduled = ref.read(dateTimeCheckboxProvider);

      final bookDateStr =
          "${DateTime.now().year.toString().padLeft(4, '0')}-"
          "${DateTime.now().month.toString().padLeft(2, '0')}-"
          "${DateTime.now().day.toString().padLeft(2, '0')} "
          "${DateTime.now().hour.toString().padLeft(2, '0')}:"
          "${DateTime.now().minute.toString().padLeft(2, '0')}:"
          "${DateTime.now().second.toString().padLeft(2, '0')}";

      final rideDate = isScheduled
          ? DateTime(
              selectedDate.year,
              selectedDate.month,
              selectedDate.day,
              selectedTime.hour,
              selectedTime.minute,
            )
          : DateTime.now();

      final rideDateStr =
          "${rideDate.year.toString().padLeft(4, '0')}-"
          "${rideDate.month.toString().padLeft(2, '0')}-"
          "${rideDate.day.toString().padLeft(2, '0')} "
          "${rideDate.hour.toString().padLeft(2, '0')}:"
          "${rideDate.minute.toString().padLeft(2, '0')}";

      final selectedPayment = ref.read(selectedPaymentProvider);

      final fromPos = ref.read(fromLatLngProvider);
      final toPos = ref.read(toLatLngProvider);

      final fromLatLongStr = "${fromPos?.latitude},${fromPos?.longitude}";
      final toLatLongStr = "${toPos?.latitude},${toPos?.longitude}";

      final booking = BookingModel(
        userid: await userId,
        mobileNo: await mobileNo,
        riderId: "",
        bookDate: bookDateStr,
        scheduled: isScheduled ? "Y" : "N",
        rideDate: rideDateStr,
        pickupLocation: pickupAddress,
        dropLocation: dropAddress,
        distance: selected['distanceKm']?.toString() ?? "0",
        fareAmount: selected['price'] ?? "0",
        vehSubTypeId: selected['typeId']?.toString() ?? "0",
        bookStatus: "B",
        paymentMethod: selectedPayment,
        driverRate: "",
        fromLatLong: fromLatLongStr.toString(),
        toLatLong: toLatLongStr.toString(),
      );

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final lastBookingId = await repository.addBooking(booking);

        // Close loading dialog
        Navigator.of(context, rootNavigator: true).pop();

        if (lastBookingId != null) {
          await SharedPrefsHelper.setLastBookingId(lastBookingId.toString());

          if (isScheduled) {
            // Show success SnackBar
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Trip Booked Successfully")),
            );
          }

          // Small delay to ensure SnackBar shows
          await Future.delayed(const Duration(milliseconds: 200));

          // Navigate based on scheduled flag
          context.push(isScheduled ? '/home' : '/searching');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Booking failed. Please try again.")),
          );
        }
      } catch (e) {
        // Close loading dialog if error
        Navigator.of(context, rootNavigator: true).pop();

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to confirm ride: $e")));
      } finally {
        isBooking = false;
      }
    }

    return MainScaffold(
      title: "Confirm Ride",
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ride Type Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.deepPurple.shade100,
                    child: Icon(
                      selected['icon'] ?? Icons.local_taxi,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selected['type'] ?? '',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        "₹ ${selected['price'] ?? ''}",
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Address Box with Date & Time Picker
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pickup Address
                  Row(
                    children: const [
                      Icon(Icons.location_on, size: 18, color: Colors.green),
                      SizedBox(width: 6),
                      Text(
                        "Pickup Address",
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(pickupAddress, style: const TextStyle(fontSize: 16)),

                  const Divider(height: 30),

                  // Drop Address
                  Row(
                    children: const [
                      Icon(Icons.flag, size: 18, color: Colors.red),
                      SizedBox(width: 6),
                      Text(
                        "Drop Address",
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(dropAddress, style: const TextStyle(fontSize: 16)),

                  const Divider(height: 30),

                  // Selectable Date & Time
                  Consumer(
                    builder: (context, ref, _) {
                      final selectedDate = ref.watch(selectedDateProvider);
                      final selectedTime = ref.watch(selectedTimeProvider);
                      final isChecked = ref.watch(dateTimeCheckboxProvider);

                      return Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              ref
                                      .read(dateTimeCheckboxProvider.notifier)
                                      .state =
                                  !isChecked;
                            },
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: isChecked
                                    ? Colors.deepPurple
                                    : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey),
                              ),
                              child: isChecked
                                  ? const Icon(
                                      Icons.check,
                                      size: 14,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Date picker
                                InkWell(
                                  onTap: isChecked
                                      ? () async {
                                          final pickedDate =
                                              await showDatePicker(
                                                context: context,
                                                initialDate: ref.read(
                                                  selectedDateProvider,
                                                ),
                                                firstDate: DateTime.now(),
                                                lastDate: DateTime(2100),
                                              );

                                          if (pickedDate != null) {
                                            final now = DateTime.now();
                                            if (pickedDate.isBefore(
                                              DateTime(
                                                now.year,
                                                now.month,
                                                now.day,
                                              ),
                                            )) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    "You cannot select a past date",
                                                  ),
                                                ),
                                              );
                                              return;
                                            }
                                            ref
                                                    .read(
                                                      selectedDateProvider
                                                          .notifier,
                                                    )
                                                    .state =
                                                pickedDate;
                                          }
                                        }
                                      : null,
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today,
                                        size: 18,
                                        color: Colors.deepPurple,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),

                                // Time picker
                                InkWell(
                                  onTap: isChecked
                                      ? () async {
                                          final now = DateTime.now();
                                          final pickedTime =
                                              await showTimePicker(
                                                context: context,
                                                initialTime: ref.read(
                                                  selectedTimeProvider,
                                                ),
                                              );

                                          if (pickedTime != null) {
                                            if (selectedDate.year == now.year &&
                                                selectedDate.month ==
                                                    now.month &&
                                                selectedDate.day == now.day) {
                                              if (pickedTime.hour < now.hour ||
                                                  (pickedTime.hour ==
                                                          now.hour &&
                                                      pickedTime.minute <=
                                                          now.minute)) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      "You cannot select a past time",
                                                    ),
                                                  ),
                                                );
                                                return;
                                              }
                                            }
                                            ref
                                                    .read(
                                                      selectedTimeProvider
                                                          .notifier,
                                                    )
                                                    .state =
                                                pickedTime;
                                          }
                                        }
                                      : null,
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.access_time,
                                        size: 18,
                                        color: Colors.deepPurple,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "${selectedTime.hourOfPeriod == 0 ? 12 : selectedTime.hourOfPeriod}:${selectedTime.minute.toString().padLeft(2, '0')} ${selectedTime.period == DayPeriod.am ? "AM" : "PM"}",
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Payment Option Section
            const Text(
              "Payment Option",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Consumer(
              builder: (context, ref, _) {
                final selectedPayment = ref.watch(selectedPaymentProvider);

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () =>
                            ref.read(selectedPaymentProvider.notifier).state =
                                "Cash",
                        child: Row(
                          children: [
                            Radio<String>(
                              value: "Cash",
                              groupValue: selectedPayment,
                              onChanged: (val) =>
                                  ref
                                          .read(
                                            selectedPaymentProvider.notifier,
                                          )
                                          .state =
                                      val!,
                            ),
                            const Text("Cash"),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () =>
                            ref.read(selectedPaymentProvider.notifier).state =
                                "UPI",
                        child: Row(
                          children: [
                            Radio<String>(
                              value: "UPI",
                              groupValue: selectedPayment,
                              onChanged: (val) =>
                                  ref
                                          .read(
                                            selectedPaymentProvider.notifier,
                                          )
                                          .state =
                                      val!,
                            ),
                            const Text("UPI"),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () =>
                            ref.read(selectedPaymentProvider.notifier).state =
                                "Card",
                        child: Row(
                          children: [
                            Radio<String>(
                              value: "Card",
                              groupValue: selectedPayment,
                              onChanged: (val) =>
                                  ref
                                          .read(
                                            selectedPaymentProvider.notifier,
                                          )
                                          .state =
                                      val!,
                            ),
                            const Text("Card"),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const Spacer(),

            // Confirm Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                  size: 20,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  if (pickupAddress == "Not selected" ||
                      dropAddress == "Not selected") {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Please select pickup & drop locations"),
                      ),
                    );
                    return;
                  }

                  showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.local_taxi,
                                size: 40,
                                color: Colors.deepPurple,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "Confirm Ride",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              "Do you want to confirm this ride booking?\nMake sure pickup, drop & payment are correct.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.black87,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: Colors.deepPurple,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      "Cancel",
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.deepPurple,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      confirmBooking(context, ref);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepPurple,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                    ),
                                    child: const Text(
                                      "Confirm",
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                label: const Text(
                  "Confirm Ride",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
