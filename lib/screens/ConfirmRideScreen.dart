import 'package:bneeds_taxi_customer/providers/location_provider.dart';
import 'package:bneeds_taxi_customer/repositories/booking_repository.dart';
import 'package:bneeds_taxi_customer/models/booking_model.dart';
import 'package:bneeds_taxi_customer/widgets/common_main_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

// add this provider (above ConfirmRideScreen)
final selectedPaymentProvider = StateProvider<String>((ref) => "Cash");

final selectedDateProvider = StateProvider<DateTime?>((ref) => DateTime.now());
final selectedTimeProvider = StateProvider<TimeOfDay?>(
  (ref) => TimeOfDay.now(),
);
final bookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => BookingRepository(),
);

class ConfirmRideScreen extends ConsumerWidget {
  const ConfirmRideScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedServiceProvider);
    print("ConfirmRideScreen sees selectedServiceProvider: $selected");

    final selectedDate = ref.watch(selectedDateProvider);
    final selectedTime = ref.watch(selectedTimeProvider);
    final fromPos = ref.read(fromLatLngProvider);
    final toPos = ref.read(toLatLngProvider);
        final pickupLocation = ref.watch(fromLocationProvider);
    final dropLocation = ref.watch(toLocationProvider);
    bool _isBooking = false;
    final pickupAddress = pickupLocation.isNotEmpty
        ? pickupLocation
        : "Not selected";
    final dropAddress = dropLocation.isNotEmpty ? dropLocation : "Not selected";

    if (selected == null) {
      return const Scaffold(body: Center(child: Text("No service selected")));
    }

    Future<void> _confirmBooking() async {
      if (_isBooking) return;
      _isBooking = true;

      final repository = ref.read(bookingRepositoryProvider);
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userid') ?? "";
      final mobileNo = prefs.getString('mobileno') ?? "";

      final now = DateTime.now();
      final bookDateStr =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} "
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
      final selectedPayment = ref.read(selectedPaymentProvider);
      final booking = BookingModel(
        userid: userId,
        mobileNo: mobileNo,
        riderId: "",
        bookDate: bookDateStr,
        scheduled: "Y",
        rideDate:
            "${selectedDate!.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}",
        pickupLocation: pickupAddress,
        dropLocation: dropAddress,
        distance: selected['distanceKm']?.toString() ?? "0",
        fareAmount: selected['price'] ?? "0",
        vehSubTypeId: selected['typeId']?.toString() ?? "0",
        bookStatus: "B",
        paymentMethod: selectedPayment,
        driverRate: "",
        fromLatLong: fromPos.toString(),
        toLatLong: toPos.toString(),
      );

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      try {
        // Call API
        final bookingId = await repository.addBooking(booking);

        Navigator.pop(context); // remove loading

        if (bookingId != null) {
          print("Booking successful, ID = $bookingId");

          // bookingId save பண்ணிக்கலாம் future use காக
          await prefs.setString("lastBookingId", bookingId.toString());

          // ✅ Booking successful → Searching screen
          context.go('/searching');
        } else {
          print("Booking failed!");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Booking failed. Please try again.")),
          );
        }
      } catch (e) {
        Navigator.pop(context); // Remove loading
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to confirm ride: $e")));
      } finally {
        _isBooking = false; // 👈 reset flag after API call
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
            // Address Box
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
                ],
              ),
            ),
            const SizedBox(height: 30),
            // Date & Time Picker
            const Text(
              "Schedule Ride",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (pickedDate != null)
                        ref.read(selectedDateProvider.notifier).state =
                            pickedDate;
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        border: Border.all(color: Colors.deepPurple.shade100),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 20,
                            color: Colors.deepPurple,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedDate != null
                                  ? "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}"
                                  : "Select Date",
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: selectedTime ?? TimeOfDay.now(),
                      );
                      if (pickedTime != null)
                        ref.read(selectedTimeProvider.notifier).state =
                            pickedTime;
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        border: Border.all(color: Colors.deepPurple.shade100),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 20,
                            color: Colors.deepPurple,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedTime != null
                                  ? selectedTime.format(context)
                                  : "Select Time",
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Payment Option Section
            const SizedBox(height: 30),
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
                              onChanged: (val) {
                                ref
                                        .read(selectedPaymentProvider.notifier)
                                        .state =
                                    val!;
                              },
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
                              onChanged: (val) {
                                ref
                                        .read(selectedPaymentProvider.notifier)
                                        .state =
                                    val!;
                              },
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
                              onChanged: (val) {
                                ref
                                        .read(selectedPaymentProvider.notifier)
                                        .state =
                                    val!;
                              },
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
                icon: Icon(
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
                  if (selectedDate == null || selectedTime == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Please select date & time"),
                      ),
                    );
                    return;
                  }
                  final selectedDateTime = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    selectedTime.hour,
                    selectedTime.minute,
                  );

                  final now = DateTime.now();
                  if (!selectedDateTime.isAfter(now)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Please choose a future time for your ride",
                        ),
                      ),
                    );
                    return;
                  }
                  // Show confirmation dialog
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
                            // Icon header
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

                            // Title
                            const Text(
                              "Confirm Ride",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 10),

                            // Message
                            const Text(
                              "Do you want to confirm this ride booking?\nMake sure pickup, drop, schedule & payment are correct.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.black87,
                                height: 1.4,
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
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
                                      _confirmBooking();
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
                label: Text(
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
