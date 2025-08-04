import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Existing provider
final selectedServiceProvider = StateProvider<Map<String, dynamic>?>(
  (ref) => null,
);

// New date & time providers
final selectedDateProvider = StateProvider<DateTime?>((ref) => null);
final selectedTimeProvider = StateProvider<TimeOfDay?>((ref) => null);

class ConfirmRideScreen extends ConsumerWidget {
  const ConfirmRideScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedServiceProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final selectedTime = ref.watch(selectedTimeProvider);

    if (selected == null) {
      return const Scaffold(body: Center(child: Text("No service selected")));
    }

    const pickupAddress = 'Simmakkal';
    const dropAddress = 'Madurai Airport';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Confirm Ride"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
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
                    child: Icon(selected['icon'], color: Colors.deepPurple),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selected['type'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        selected['price'],
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
                  const Row(
                    children: [
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

                  const Row(
                    children: [
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

            // Date & Time Picker Section
            // Date & Time Picker Section
            const Text(
              "Schedule Ride",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                // Date Picker
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(
                          const Duration(days: 1),
                        ),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (pickedDate != null) {
                        ref.read(selectedDateProvider.notifier).state =
                            pickedDate;
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors
                            .deepPurple
                            .shade50, // 🟣 Light purple background
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

                // Time Picker
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (pickedTime != null) {
                        ref.read(selectedTimeProvider.notifier).state =
                            pickedTime;
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors
                            .deepPurple
                            .shade50, // 🟣 Light purple background
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

            const Spacer(),

            // Confirm Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(
                  Icons.check_circle_outline,
                  color: Colors.white.withOpacity(0.7),
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
                  if (selectedDate == null || selectedTime == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Please select date & time first"),
                      ),
                    );
                    return;
                  }

                  // Show confirmation dialog
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => Dialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      insetPadding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 25,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.deepPurple.shade50,
                              ),
                              child: const Icon(
                                Icons.check_circle,
                                size: 48,
                                color: Colors.deepPurple,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "Ride Confirmed",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "Your ${selected['type']} is scheduled for ${selectedDate!.day}/${selectedDate.month} at ${selectedTime!.format(context)}.\nPlease be ready at pickup.",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.black87,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  ref
                                          .read(
                                            selectedServiceProvider.notifier,
                                          )
                                          .state =
                                      null;
                                  context.go('/searching');
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  "OK",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ),
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
                    color: Colors.white.withOpacity(0.7),
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
