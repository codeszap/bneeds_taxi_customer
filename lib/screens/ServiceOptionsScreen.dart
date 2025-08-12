import 'package:bneeds_taxi_customer/providers/vehicle_subtype_provider.dart';
import 'package:bneeds_taxi_customer/screens/ConfirmRideScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';



class ServiceOptionsScreen extends ConsumerWidget {
  final String vehTypeId; // Store vehTypeId

  const ServiceOptionsScreen({
    super.key,
    required this.vehTypeId,
  });

  final List<Map<String, dynamic>> services = const [
    {
      'type': 'Bike',
      'icon': Icons.motorcycle,
      'price': '₹60',
    },
    {
      'type': 'Auto',
      'icon': Icons.directions_bus,
      'price': '₹85',
    },
    {
      'type': 'Cab',
      'icon': Icons.local_taxi,
      'price': '₹130',
    },
    {
      'type': 'Parcel',
      'icon': Icons.local_shipping,
      'price': '₹50',
    },
  ];



@override
Widget build(BuildContext context, WidgetRef ref) {
  final selectedService = ref.watch(selectedServiceProvider);
  final subTypesAsync = ref.watch(vehicleSubTypeProvider(vehTypeId)); // API call

  return Scaffold(
    appBar: AppBar(
      title: const Text("Choose a Service"),
      backgroundColor: Colors.deepPurple,
      foregroundColor: Colors.white,
    ),
    body: subTypesAsync.when(
      data: (subTypes) {
        return Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(10),
                itemCount: subTypes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = subTypes[index];
                  final isSelected = selectedService?['id'] == item.vehSubTypeId;

                  return GestureDetector(
                    onTap: () {
                      ref.read(selectedServiceProvider.notifier).state = {
                        'id': item.vehSubTypeId,
                        'type': item.vehSubTypeName,
                        'price': item.price ?? '0'
                      };
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: isSelected
                            ? Border.all(color: Colors.blue, width: 2)
                            : Border.all(color: Colors.transparent),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        leading: CircleAvatar(
                          backgroundColor: Colors.deepPurple.shade100,
                          child: const Icon(Icons.local_taxi,
                              color: Colors.deepPurple),
                        ),
                        title: Text(
                          item.vehSubTypeName ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 17),
                        ),
                        subtitle: const Padding(
                          padding: EdgeInsets.only(top: 4.0),
                          child: Text(
                            "1 min away · Drop: 1:39 PM",
                            style: TextStyle(
                                fontSize: 13, color: Colors.black54),
                          ),
                        ),
                        trailing: Text(
                          "₹${item.price ?? '0'}",
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Book Ride Button
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      if (selectedService == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a service first'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ConfirmRideScreen(),
                        ),
                      );
                    },
                    child: Text(
                      "Book Ride",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withOpacity(0.9)),
                    ),
                  ),
                ),
              ),
            )
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text("Error: $err")),
    ),
  );
}

}
