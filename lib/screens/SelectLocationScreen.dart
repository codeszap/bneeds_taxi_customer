import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final fromLocationProvider = StateProvider<String>((ref) => 'Current Location');
final toLocationProvider = StateProvider<String>((ref) => 'Madurai Airport');


class SelectLocationScreen extends ConsumerWidget {
  const SelectLocationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fromLocation = ref.watch(fromLocationProvider);
    final toLocation = ref.watch(toLocationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Location"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // From Location
              _buildLocationCard(
                title: "From",
                value: fromLocation,
                icon: Icons.my_location,
                onTap: () {
               //   ref.read(fromLocationProvider.notifier).state = location;
                  context.push('/service-options');
                },
              ),
              const SizedBox(height: 12),

              // To Location
              _buildLocationCard(
                title: "To",
                value: toLocation,
                icon: Icons.place_outlined,
                onTap: () {
             //  ref.read(toLocationProvider.notifier).state = location;
          context.push('/service-options');
                },
              ),

              const SizedBox(height: 20),

              // Map Selector
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Show map screen or picker
                  },
                  icon: const Icon(Icons.map_outlined),
                  label: const Text("Select on Map"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Recent Locations
              const Row(
                children: [
                  Text(
                    "📍 Recent Locations",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              _buildRecentLocationTile(
                context,
                ref,
                location: "Simmakkal",
                subLocation: "Madurai, Madurai Municipal Corporation",
              ),
              _buildRecentLocationTile(
                context,
                ref,
                location: "Periyar Bus Stand",
                subLocation: "Madurai, East Avani Moola Street",
              ),
              _buildRecentLocationTile(
                context,
                ref,
                location: "Madurai Airport",
                subLocation: "Madurai, Airport Road",
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationCard({
    required String title,
    required String value,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.deepPurple),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildRecentLocationTile(
    BuildContext context,
    WidgetRef ref, {
    required String location,
    required String subLocation,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.transparent),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: ListTile(
        leading: const Icon(Icons.history, color: Colors.grey),
        title: Text(location,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          subLocation,
          style: const TextStyle(fontSize: 13, color: Colors.black54),
        ),
        trailing: const Icon(Icons.favorite_border, color: Colors.grey),
        onTap: () {
          // Set selected location
          ref.read(toLocationProvider.notifier).state = location;
          context.push('/service-options');
        },
      ),
    );
  }
}
