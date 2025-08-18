import 'dart:convert';

import 'package:bneeds_taxi_customer/providers/location_provider.dart';
import 'package:bneeds_taxi_customer/screens/SelectLocationScreen.dart';
import 'package:bneeds_taxi_customer/widgets/common_main_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../../widgets/common_appbar.dart';
import '../../widgets/common_drawer.dart';
import '../../providers/vehicle_type_provider.dart';
import '../../providers/recent_rides_provider.dart';

// Google API Key
const String _googleApiKey = "AIzaSyAWzUqf3Z8xvkjYV7F4gOGBBJ5d_i9HZhs";
// Recent locations
final recentLocationsProvider =
    StateNotifierProvider<RecentLocationsNotifier, List<Map<String, String>>>(
      (ref) => RecentLocationsNotifier(),
    );
// ---- Google Suggestions Provider ----
final placeSuggestionsProvider = FutureProvider.family<List<String>, String>((
  ref,
  query,
) async {
  if (query.isEmpty) return [];
  final url = Uri.parse(
    "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(query)}&key=$_googleApiKey&components=country:in",
  );
  final response = await http.get(url);
  final jsonBody = jsonDecode(response.body);
  if (jsonBody["status"] == "OK") {
    return (jsonBody["predictions"] as List)
        .map((e) => e["description"] as String)
        .toList();
  } else {
    return [];
  }
});

// ---- Helper: Position -> Address ----
Future<String> getAddressFromPosition(Position position) async {
  List<Placemark> placemarks = await placemarkFromCoordinates(
    position.latitude,
    position.longitude,
  );
  if (placemarks.isNotEmpty) {
    final placemark = placemarks.first;
    return "${placemark.name}, ${placemark.locality}, ${placemark.country}";
  }
  return "${position.latitude}, ${position.longitude}";
}

// ---- MAIN SCREEN ----
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleTypesAsync = ref.watch(vehicleTypesProvider);
    final recentRidesAsync = ref.watch(recentRidesProvider("U001"));

    final fromLocation = ref.watch(fromLocationProvider);
    final toLocation = ref.watch(toLocationProvider);
    final query = ref.watch(placeQueryProvider);
    final suggestionsAsync = ref.watch(placeSuggestionsProvider(query));

    final serviceList = [
      {'type': 'car', 'icon': Icons.local_taxi, 'color': Colors.deepPurple},
      {'type': 'auto', 'icon': Icons.directions_bus, 'color': Colors.orange},
      {'type': 'parcel', 'icon': Icons.local_shipping, 'color': Colors.green},
      {'type': 'bike', 'icon': Icons.motorcycle, 'color': Colors.blue},
    ];

    return MainScaffold(
         title: "Home",
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(vehicleTypesProvider);
          ref.invalidate(recentRidesProvider("U001"));
          await Future.wait([
            ref.read(vehicleTypesProvider.future),
            ref.read(recentRidesProvider("U001").future),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '👋 Hello, Bneeds!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // ---- FROM LOCATION ----
              _LocationField(
                label: "From",
                isFrom: true,
                icon: Icons.my_location,
                onChanged: (val) {
                  ref.read(fromLocationProvider.notifier).state = val;
                  ref.read(placeQueryProvider.notifier).state = val;
                },
                onSuggestionTap: (val) {
                  ref.read(fromLocationProvider.notifier).state = val;
                  ref.read(placeQueryProvider.notifier).state = '';
                  FocusScope.of(context).unfocus();
                },
                suffixIcon: IconButton(
                  icon: const Icon(Icons.gps_fixed, color: Colors.deepPurple),
                  onPressed: () async {
                    try {
                      final pos = await ref.read(
                        currentLocationProvider.future,
                      );
                      final address = await getAddressFromPosition(pos);
                      ref.read(fromLocationProvider.notifier).state = address;
                      FocusScope.of(context).unfocus();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Location error: $e")),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),

              // ---- TO LOCATION ----
              _LocationField(
                label: "To",
                isFrom: false,
                icon: Icons.place_outlined,
                onChanged: (val) {
                  ref.read(toLocationProvider.notifier).state = val;
                  ref.read(placeQueryProvider.notifier).state = val;
                },
                onSuggestionTap: (val) {
                  ref.read(toLocationProvider.notifier).state = val;
                  ref.read(placeQueryProvider.notifier).state = '';
                  FocusScope.of(context).unfocus();
                },
              ),

              const SizedBox(height: 20),
            _buildMapButton(context, ref),
              const SizedBox(height: 20),
              // ---- Suggestions ----
              suggestionsAsync.when(
                data: (list) {
                  if (list.isEmpty) return const SizedBox();
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final location = list[index];
                      final isFrom = query == fromLocation;
                      return ListTile(
                        tileColor: Colors.grey[100],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        leading: const Icon(
                          Icons.place_outlined,
                          color: Colors.deepPurple,
                        ),
                        title: Text(location),
                        onTap: () {
                          if (isFrom) {
                            ref.read(fromLocationProvider.notifier).state =
                                location;
                          } else {
                            ref.read(toLocationProvider.notifier).state =
                                location;
                          }
                          ref.read(placeQueryProvider.notifier).state = '';
                          FocusScope.of(context).unfocus();
                        },
                      );
                    },
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(8),
                  child: LinearProgressIndicator(),
                ),
                error: (_, __) => const SizedBox(),
              ),

              const SizedBox(height: 20),

              // ---- VEHICLE TYPES ----
              const Text(
                "🚖 Choose a Service",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              vehicleTypesAsync.when(
                data: (vehicleTypes) {
                  if (vehicleTypes.isEmpty) {
                    return const Text("No services available");
                  }
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: vehicleTypes.map((type) {
                        final style = serviceList.firstWhere(
                          (s) =>
                              s['type'].toString().toLowerCase() ==
                              type.vehTypeName.toLowerCase(),
                          orElse: () => {
                            'icon': Icons.directions_car,
                            'color': Colors.grey,
                          },
                        );
                        return GestureDetector(
                          onTap: () {
                            context.push(
                              '/service-options',
                              extra: type.vehTypeid,
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: (style['color'] as Color).withOpacity(
                                  0.2,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  backgroundColor: (style['color'] as Color)
                                      .withOpacity(0.15),
                                  child: Icon(
                                    style['icon'] as IconData,
                                    color: style['color'] as Color,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(type.vehTypeName),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Text("Error: $err"),
              ),

              const SizedBox(height: 30),
              // ---- RECENT RIDES ----
              const Text(
                "🕓 Recent Rides",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),

              // ---- Manual Ride from From/To ----
              if (fromLocation.isNotEmpty && toLocation.isNotEmpty)
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(
                      Icons.local_taxi,
                      color: Colors.deepPurple,
                    ),
                    title: Text("$fromLocation → $toLocation"),
                    subtitle: const Text("Manual Selection"),
                    trailing: const Text(
                      "₹--",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

   Widget _buildMapButton(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          final selectedAddress = await context.push<String>('/select-on-map');
          if (selectedAddress != null && selectedAddress.isNotEmpty) {
            ref.read(toLocationProvider.notifier).state = selectedAddress;
            ref.read(placeQueryProvider.notifier).state = '';
            ref
                .read(recentLocationsProvider.notifier)
                .addLocation(selectedAddress);
          }
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
    );
  }

}

// ---- Reusable Location Field ----
class _LocationField extends ConsumerStatefulWidget {
  final String label;
  final bool isFrom;
  final IconData icon;
  final Widget? suffixIcon;
  final Function(String) onChanged;
  final Function(String) onSuggestionTap;

  const _LocationField({
    required this.label,
    required this.isFrom,
    required this.icon,
    required this.onChanged,
    required this.onSuggestionTap,
    this.suffixIcon,
    super.key,
  });

  @override
  ConsumerState<_LocationField> createState() => _LocationFieldState();
}

class _LocationFieldState extends ConsumerState<_LocationField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.isFrom
        ? ref.watch(fromLocationProvider)
        : ref.watch(toLocationProvider);

    if (_controller.text != value) {
      _controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }

    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: Icon(widget.icon, color: Colors.deepPurple),
        suffixIcon: widget.suffixIcon,
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
        ),
      ),
    );
  }
}
