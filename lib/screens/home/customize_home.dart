import 'dart:convert';

import 'package:bneeds_taxi_customer/models/location_data.dart';
import 'package:bneeds_taxi_customer/models/vehicle_subtype_model.dart';
import 'package:bneeds_taxi_customer/providers/location_provider.dart';
import 'package:bneeds_taxi_customer/providers/vehicle_subtype_provider.dart';
import 'package:bneeds_taxi_customer/screens/ConfirmRideScreen.dart'
    hide selectedServiceProvider;
import 'package:bneeds_taxi_customer/screens/SelectLocationScreen.dart'
    hide recentLocationsProvider, placeSuggestionsProvider;
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

class PlaceSuggestion {
  final String description;
  final String placeId;

  PlaceSuggestion({required this.description, required this.placeId});

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    return PlaceSuggestion(
      description: json["description"],
      placeId: json["place_id"],
    );
  }
}

class RouteInfo {
  final double distanceKm;
  final String distanceText;
  final int durationMinutes;
  final String durationText;

  RouteInfo({
    required this.distanceKm,
    required this.distanceText,
    required this.durationMinutes,
    required this.durationText,
  });
}

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
  Map<String, dynamic>? _selectedVehicleType; // selected vehicle type
  RouteInfo? _selectedSubType; // selected subtype
  //Map<String, dynamic>? _routeInfo; // distance/time
  RouteInfo? _routeInfo;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchLocation();
    Future.delayed(Duration(seconds: 2), () {
      _fetchLocation();
    });
    _loadSessionData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

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
      ref.read(fromLatLngProvider.notifier).state = pos;
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Please enable location: $e")));

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

  Future<RouteInfo> getRouteInfo(Position fromPos, Position toPos) async {
    final url = Uri.parse(
      "https://maps.googleapis.com/maps/api/directions/json"
      "?origin=${fromPos.latitude},${fromPos.longitude}"
      "&destination=${toPos.latitude},${toPos.longitude}"
      "&key=${Strings.googleApiKey}",
    );

    final response = await http.get(url);
    final data = jsonDecode(response.body);

    if (data["status"] == "OK") {
      final route = data["routes"][0];
      final leg = route["legs"][0];

      return RouteInfo(
        distanceKm: leg["distance"]["value"] / 1000,
        distanceText: leg["distance"]["text"],
        durationMinutes: (leg["duration"]["value"] / 60).round(),
        durationText: leg["duration"]["text"],
      );
    } else {
      throw Exception("Directions API error: ${data["status"]}");
    }
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

    // Vehicle Subtypes Async
    AsyncValue<List<VehicleSubType>> subTypesAsync() {
      if (_selectedVehicleType != null &&
          fromLocation.isNotEmpty &&
          toLocation.isNotEmpty &&
          _routeInfo != null) {
        return ref.watch(
          vehicleSubTypeProvider((
            _selectedVehicleType!['vehTypeid'].toString(),
            _routeInfo!.distanceKm.toString(),
          )),
        );
      }
      return AsyncValue.data([]);
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
              // Greeting
              Text(
                '👋 Hello, ${_username ?? ""}!',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // From Location
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

                      // Print raw position
                      print(
                        "📍 Current Position: lat=${pos.latitude}, lng=${pos.longitude}",
                      );

                      final address = await getAddressFromPosition(pos);

                      // Print converted address
                      print("🏠 Current Address: $address");

                      ref.read(fromLocationProvider.notifier).state = address;
                      FocusScope.of(context).unfocus();
                    } catch (e) {
                      print("❌ Location error: $e");
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Location error: $e")),
                      );
                    }
                  },
                ),
              ),

              const SizedBox(height: 12),

              // To Location
              Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: LocationField(
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
                  ),
                  SizedBox(width: 10),
                  Expanded(child: _buildMapButton(context, ref)),
                ],
              ),

              const SizedBox(height: 5),

              // Suggestions
              suggestionsAsync.when(
                data: (list) {
                  if (list.isEmpty) return const SizedBox();
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final suggestion = list[index]; // PlaceSuggestion object
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
                        title: Text(suggestion.description),
                        onTap: () async {
                          if (isFrom) {
                            ref.read(fromLocationProvider.notifier).state =
                                suggestion.description;

                            final pos = await getLatLngFromAddress(
                              suggestion.placeId,
                            );
                            if (pos != null) {
                              ref.read(fromLatLngProvider.notifier).state = pos;

                              // 🔹 Print From Lat/Lng
                              print(
                                "From Lat: ${pos.latitude}, Lng: ${pos.longitude}",
                              );
                            }
                          } else {
                            ref.read(toLocationProvider.notifier).state =
                                suggestion.description;

                            final pos = await getLatLngFromAddress(
                              suggestion.placeId,
                            );
                            if (pos != null) {
                              ref.read(toLatLngProvider.notifier).state = pos;

                              // 🔹 Print To Lat/Lng
                              print(
                                "To Lat: ${pos.latitude}, Lng: ${pos.longitude}",
                              );
                            }
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

              // Vehicle Types
              const Text(
                "🚖 Choose a Service",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              vehicleTypesAsync.when(
                data: (vehicleTypes) {
                  if (vehicleTypes.isEmpty) return const Text("No services");
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

                        final isSelected =
                            _selectedVehicleType != null &&
                            _selectedVehicleType!['vehTypeid'] ==
                                type.vehTypeid;

                        return GestureDetector(
                          onTap: () async {
                            final fromPos = ref.read(fromLatLngProvider);
                            final toPos = ref.read(toLatLngProvider);

                            if (fromPos == null || toPos == null) {
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
                              final routeInfo = await getRouteInfo(
                                fromPos,
                                toPos,
                              );
                              setState(() {
                                _routeInfo = routeInfo;
                                _selectedVehicleType = {
                                  'vehTypeid': type.vehTypeid,
                                  'vehTypeName': type.vehTypeName,
                                };
                                _selectedSubType = null;
                              });
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
                                color: isSelected
                                    ? (style['color'] as Color)
                                    : Colors.transparent,
                                width: 2,
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

              const SizedBox(height: 20),

              // Vehicle Subtypes
              if (_selectedVehicleType != null && _routeInfo != null)
             
                subTypesAsync().when(
                  data: (subTypes) {
                    if (subTypes.isEmpty) {
                      return Center(
                        child: Column(
                          children: [
                            SizedBox(height: 100),
                            const Text(
                              "Please Select Service First",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        const Text(
                          "Choose a subtype",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: subTypes.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = subTypes[index];

                            // Watch selectedServiceProvider instead of _selectedSubType
                            final selectedService = ref.watch(
                              selectedServiceProvider,
                            );
                            final isSelected =
                                selectedService != null &&
                                selectedService['typeId'] == item.vehSubTypeId;

                            return GestureDetector(
                              onTap: () {
                                ref
                                    .read(selectedServiceProvider.notifier)
                                    .state = {
                                  'typeId': item.vehSubTypeId,
                                  'type': item.vehSubTypeName,
                                  'price': item.totalKms ?? '0',
                                  'distanceKm': _routeInfo!.distanceKm
                                      .toStringAsFixed(2),
                                  'durationMin': _routeInfo!.durationText,
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
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.deepPurple.shade100,
                                    child: const Icon(
                                      Icons.local_taxi,
                                      color: Colors.deepPurple,
                                    ),
                                  ),
                                  title: Text(
                                    item.vehSubTypeName ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 17,
                                    ),
                                  ),
                                  subtitle: Text(
                                    "Distance: ${_routeInfo!.distanceKm.toStringAsFixed(2)} km · Est. Drop: ${_routeInfo!.durationText}",

                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  trailing: Text(
                                    "₹${(item.totalKms == null || item.totalKms!.isEmpty) ? '00.0' : item.totalKms}",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        // Book Ride Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                ref.watch(selectedServiceProvider) == null
                                ? null
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const ConfirmRideScreen(),
                                      ),
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  ref.watch(selectedServiceProvider) != null
                                  ? Colors.deepPurple
                                  : Colors.grey,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              "Book Ride",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text("Error: $err")),
                ),

              const SizedBox(height: 30),
              // // Recent Rides
              // const Text(
              //   "🕓 Recent Rides",
              //   style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              // ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapButton(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        final selectedAddress = await context.push<String>('/select-on-map');
        if (selectedAddress != null && selectedAddress.isNotEmpty) {
          ref.read(toLocationProvider.notifier).state = selectedAddress;
          ref.read(placeQueryProvider.notifier).state = '';
          ref
              .read(recentLocationsProvider.notifier)
              .addLocation(selectedAddress);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.deepPurple,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.map_outlined, color: Colors.white, size: 28),
      ),
    );
  }
}
