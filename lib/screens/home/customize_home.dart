import 'dart:convert';

import 'package:bneeds_taxi_customer/models/location_data.dart';
import 'package:bneeds_taxi_customer/providers/location_provider.dart';
import 'package:bneeds_taxi_customer/screens/SelectLocationScreen.dart' hide recentLocationsProvider, placeSuggestionsProvider;
import 'package:bneeds_taxi_customer/screens/home/widget/LocationField.dart';
import 'package:bneeds_taxi_customer/utils/constants.dart';

import 'package:bneeds_taxi_customer/widgets/common_main_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../widgets/common_appbar.dart';
import '../../../widgets/common_drawer.dart';
import '../../../providers/vehicle_type_provider.dart';
import '../../../providers/recent_rides_provider.dart';




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

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  String? _username;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Screen open ஆனவுடன் fetch பண்ணு
    _fetchLocation();
    _loadSessionData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // App lifecycle change (settings-ல இருந்து திரும்ப வந்ததும் call ஆகும்)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchLocation();
    }
  }

  Future<void> _fetchLocation() async {
    try {
      final pos = await ref.read(currentLocationProvider.future);
      final address = await getAddressFromPosition(pos);
      ref.read(fromLocationProvider.notifier).state = address;
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Please enable location: $e")));

      // Service off இருந்தா → location settings open பண்ணு
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
      }
    }
  }

  Future<void> _loadSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? "Guest";
    });
  }

  @override
  Widget build(BuildContext context) {
    final vehicleTypesAsync = ref.watch(vehicleTypesProvider);

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

    Future<Map<String, dynamic>> getRouteInfo(String from, String to) async {
      final url = Uri.parse(
        "https://maps.googleapis.com/maps/api/directions/json?"
        "origin=${Uri.encodeComponent(from)}"
        "&destination=${Uri.encodeComponent(to)}"
        "&mode=driving"
        "&key=${Strings.googleApiKey}",
      );

      final response = await http.get(url);
      final data = jsonDecode(response.body);

      if (data["status"] == "OK") {
        final leg = data["routes"][0]["legs"][0];

        final distanceMeters = leg["distance"]["value"]; // meters
        final durationSeconds = leg["duration"]["value"]; // seconds
        final durationText = leg["duration"]["text"]; // e.g. "32 mins"

        return {
          "distanceKm": distanceMeters / 1000,
          "durationText": durationText,
          "durationMinutes": durationSeconds / 60,
        };
      } else {
        throw Exception("Google Directions error: ${data["status"]}");
      }
    }

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
              Text(
                '👋 Hello, ${_username ?? ""}!',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // ---- FROM LOCATION ----
              LocationField(
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
              LocationField(
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
                          // onTap: () {
                          //   context.push(
                          //     '/service-options',
                          //     extra: {
                          //       'vehTypeId': type.vehTypeid,
                          //       'totalKms': "10",
                          //     },
                          //   );
                          // },
                          onTap: () async {
                            final from = ref.read(fromLocationProvider);
                            final to = ref.read(toLocationProvider);

                            if (from.isEmpty || to.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Please select From & To Location",
                                  ),
                                ),
                              );
                              return;
                            }

                            try {
                              // ✅ Route distance from Google
                              final routeInfo = await getRouteInfo(from, to);

                              context.push(
                                '/service-options',
                                extra: {
                                  'vehTypeId': type.vehTypeid,
                                  'totalKms': routeInfo["distanceKm"]
                                      .toStringAsFixed(2), // e.g. 12.35
                                  'estTime':
                                      routeInfo["durationText"], // e.g. "32 mins"
                                },
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Distance error: $e")),
                              );
                            }
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
              (fromLocation.isNotEmpty && toLocation.isNotEmpty)
                  ? GestureDetector(
                      onTap: () async {
                        final vehicleTypes = await ref.read(
                          vehicleTypesProvider.future,
                        );

                        if (vehicleTypes.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("No services available"),
                            ),
                          );
                          return;
                        }

                        final selectedVehicle =
                            vehicleTypes.first; // first vehicle type as default

                        try {
                          final routeInfo = await getRouteInfo(
                            fromLocation,
                            toLocation,
                          );

                          context.push(
                            '/service-options',
                            extra: {
                              'vehTypeId': selectedVehicle
                                  .vehTypeid, // pass actual vehicle ID
                              'totalKms': routeInfo["distanceKm"]
                                  .toStringAsFixed(2),
                              'estTime': routeInfo["durationText"],
                              'from': fromLocation,
                              'to': toLocation,
                            },
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Distance error: $e")),
                          );
                        }
                      },
                      child: Card(
                        elevation: 3, // light shadow
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // From dot
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      fromLocation,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  // To dot
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      toLocation,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 120),
                          const Text(
                            "No rides",
                            style: TextStyle(
                              fontSize: 19,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
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

