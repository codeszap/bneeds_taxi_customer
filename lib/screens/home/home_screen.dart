import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/common_appbar.dart';
import '../../widgets/common_drawer.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  final List<Map<String, dynamic>> actions = const [
    {
      'type': 'Bike',
      'icon': Icons.motorcycle,
      'color': Colors.deepPurple,
    },
    {
      'type': 'Auto',
      'icon': Icons.directions_bus,
      'color': Colors.orange,
    },
    {
      'type': 'Cab',
      'icon': Icons.local_taxi,
      'color': Colors.green,
    },
    {
      'type': 'Parcel',
      'icon': Icons.local_shipping,
      'color': Colors.blue,
    },
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      drawer: CommonDrawer(onLogout: () {}),
      appBar: CommonAppBar(
        title: "Home",
        showSearch: true,
        onSearchChanged: (text) {
          print("User searched: $text");
        },
        actions: [
          IconButton(icon: const Icon(Icons.notifications,color: Colors.white), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '👋 Hello, Bneeds!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "What would you like to do today?",
              style: TextStyle(fontSize: 15, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            /// List-style Quick Actions (Service Option style)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: actions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = actions[index];
                return GestureDetector(
                  onTap: () {
                    context.push('/select-location');
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.deepPurple.shade100, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurple.withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              (item['color'] as Color).withOpacity(0.15),
                          radius: 26,
                          child: Icon(
                            item['icon'] as IconData,
                            color: item['color'] as Color,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['type'] as String,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "Nearby options available",
                                style: TextStyle(
                                    fontSize: 13, color: Colors.black54),
                              )
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios,
                            size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 30),
            const Text(
              "🕓 Recent Rides",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            _buildRecentRideTile(
              date: "Aug 1, 2025",
              destination: "Simmakkal",
              fare: "₹120",
            ),
            _buildRecentRideTile(
              date: "Jul 28, 2025",
              destination: "Periyar Bus Stand",
              fare: "₹85",
            ),
            _buildRecentRideTile(
              date: "Jul 25, 2025",
              destination: "Madurai Airport",
              fare: "₹132",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentRideTile({
    required String date,
    required String destination,
    required String fare,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.local_taxi, color: Colors.deepPurple),
        title: Text(destination),
        subtitle: Text(date),
        trailing: Text(
          fare,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
