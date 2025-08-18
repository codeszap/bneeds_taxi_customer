// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:go_router/go_router.dart';
// import '../../widgets/common_appbar.dart';
// import '../../widgets/common_drawer.dart';
// import '../../providers/vehicle_type_provider.dart';
// import '../../providers/recent_rides_provider.dart';

// class HomeScreen extends ConsumerWidget {
//   const HomeScreen({super.key});

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final vehicleTypesAsync = ref.watch(vehicleTypesProvider);
//     final recentRidesAsync = ref.watch(recentRidesProvider("U001"));

//     // Manual style mapping for UI
//     final serviceList = [
//       {'type': 'car', 'icon': Icons.local_taxi, 'color': Colors.deepPurple},
//       {'type': 'auto', 'icon': Icons.directions_bus, 'color': Colors.orange},
//       {'type': 'parcel', 'icon': Icons.local_shipping, 'color': Colors.green},
//       {'type': 'bike', 'icon': Icons.motorcycle, 'color': Colors.blue},
//     ];

//     return Scaffold(
//       drawer: CommonDrawer(),
//       appBar: CommonAppBar(
//         title: "Home",
//         showSearch: true,
//         onSearchChanged: (text) {
//           debugPrint("User searched: $text");
//         },
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.notifications, color: Colors.white),
//             onPressed: () {},
//           ),
//         ],
//       ),
//       body: RefreshIndicator(
//         onRefresh: () async {
//           // Refresh both providers on pull
//           ref.invalidate(vehicleTypesProvider);
//           ref.invalidate(recentRidesProvider("U001"));
//           // wait for some time or until both refresh
//           await Future.wait([
//             ref.read(vehicleTypesProvider.future),
//             ref.read(recentRidesProvider("U001").future),
//           ]);
//         },
//         child: SingleChildScrollView(
//           physics: const AlwaysScrollableScrollPhysics(),
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text(
//                 '👋 Hello, Bneeds!',
//                 style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 8),
//               const Text(
//                 "What would you like to do today?",
//                 style: TextStyle(fontSize: 15, color: Colors.grey),
//               ),
//               const SizedBox(height: 24),

//               /// Vehicle Types (Styled)
//               vehicleTypesAsync.when(
//                 data: (vehicleTypes) {
//                   if (vehicleTypes.isEmpty) {
//                     return const Text("No services available");
//                   }
//                   return ListView.separated(
//                     shrinkWrap: true,
//                     physics: const NeverScrollableScrollPhysics(),
//                     itemCount: vehicleTypes.length,
//                     separatorBuilder: (_, __) => const SizedBox(height: 12),
//                     itemBuilder: (context, index) {
//                       final type = vehicleTypes[index];

//                       final style = serviceList.firstWhere(
//                         (s) =>
//                             s['type'].toString().toLowerCase() ==
//                             type.vehTypeName.toLowerCase(),
//                         orElse: () => {
//                           'icon': Icons.directions_car,
//                           'color': Colors.grey,
//                         },
//                       );

//                       return GestureDetector(
//                         onTap: () {
//                           final vehTypeId = vehicleTypes[index].vehTypeid;
//                           context.push('/select-location', extra: vehTypeId);
//                         },
//                         child: Container(
//                           decoration: BoxDecoration(
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(12),
//                             border: Border.all(
//                               color: (style['color'] as Color).withOpacity(0.2),
//                             ),
//                             boxShadow: [
//                               BoxShadow(
//                                 color: (style['color'] as Color).withOpacity(0.05),
//                                 blurRadius: 8,
//                                 offset: const Offset(0, 2),
//                               ),
//                             ],
//                           ),
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 14,
//                             vertical: 12,
//                           ),
//                           child: Row(
//                             children: [
//                               CircleAvatar(
//                                 backgroundColor:
//                                     (style['color'] as Color).withOpacity(0.15),
//                                 radius: 26,
//                                 child: Icon(
//                                   style['icon'] as IconData,
//                                   color: style['color'] as Color,
//                                   size: 28,
//                                 ),
//                               ),
//                               const SizedBox(width: 16),
//                               Expanded(
//                                 child: Column(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   children: [
//                                     Text(
//                                       type.vehTypeName,
//                                       style: const TextStyle(
//                                         fontSize: 16,
//                                         fontWeight: FontWeight.w600,
//                                       ),
//                                     ),
//                                     const SizedBox(height: 4),
//                                     const Text(
//                                       "Nearby options available",
//                                       style: TextStyle(
//                                         fontSize: 13,
//                                         color: Colors.black54,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                               const Icon(
//                                 Icons.arrow_forward_ios,
//                                 size: 16,
//                                 color: Colors.grey,
//                               ),
//                             ],
//                           ),
//                         ),
//                       );
//                     },
//                   );
//                 },
//                 loading: () => const Center(child: CircularProgressIndicator()),
//                 error: (err, _) => Text("Error loading vehicle types: $err"),
//               ),

//               const SizedBox(height: 30),

//               /// Recent Rides
//               const Text(
//                 "🕓 Recent Rides",
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
//               ),
//               const SizedBox(height: 10),

//               recentRidesAsync.when(
//                 data: (rides) {
//                   if (rides.isEmpty) {
//                     return const Text("No recent rides found");
//                   }
//                   return ListView.builder(
//                     shrinkWrap: true,
//                     physics: const NeverScrollableScrollPhysics(),
//                     itemCount: rides.length,
//                     itemBuilder: (context, index) {
//                       final ride = rides[index];
//                       return Card(
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         margin: const EdgeInsets.only(bottom: 12),
//                         child: ListTile(
//                           leading: const Icon(
//                             Icons.local_taxi,
//                             color: Colors.deepPurple,
//                           ),
//                           title: Text(
//                             "${ride.pickupLocation} → ${ride.dropLocation}",
//                           ),
//                           subtitle: Text(ride.rideDate),
//                           trailing: Text(
//                             "₹${ride.fareAmount.toStringAsFixed(0)}",
//                             style: const TextStyle(fontWeight: FontWeight.bold),
//                           ),
//                         ),
//                       );
//                     },
//                   );
//                 },
//                 loading: () => const Center(child: CircularProgressIndicator()),
//                 error: (err, _) => Text("Error loading recent rides: $err"),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
