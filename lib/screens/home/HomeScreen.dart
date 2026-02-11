import 'dart:async';
import 'dart:convert';

import 'package:bneeds_taxi_customer/models/location_data.dart';
import 'package:bneeds_taxi_customer/models/vehicle_subtype_model.dart';
import 'package:bneeds_taxi_customer/providers/location_provider.dart';
import 'package:bneeds_taxi_customer/providers/vehicle_subtype_provider.dart';
import 'package:bneeds_taxi_customer/screens/select_location_screen.dart'
    hide recentLocationsProvider, placeSuggestionsProvider;
import 'package:bneeds_taxi_customer/screens/home/widget/LocationField.dart';
import 'package:bneeds_taxi_customer/utils/constants.dart';
import 'package:bneeds_taxi_customer/widgets/common_main_scaffold.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import '../../providers/trip_status_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../widgets/common_appbar.dart';
import '../../../widgets/common_drawer.dart';
import '../../../widgets/common_shimmer.dart';
import '../../../providers/vehicle_type_provider.dart';
import '../../../providers/recent_rides_provider.dart';
import '../../core/locationHelper.dart';

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

// // ---- Helper: Position -> Address ----
// Future<String> getAddressFromPosition(Position position) async {
//   List<Placemark> placemarks = await placemarkFromCoordinates(
//     position.latitude,
//     position.longitude,
//   );
//   if (placemarks.isNotEmpty) {
//     final placemark = placemarks.first;
//     return "${placemark.name}, ${placemark.locality}, ${placemark.country}";
//   }
//   return "${position.latitude}, ${position.longitude}";
// }

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
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLocationAndSetFromField();
    _loadSessionData();
  }

  Future<void> _checkLocationAndSetFromField() async {
    final hasPermission = await LocationHelper.checkAndRequestPermission(
      context,
    );

    if (!hasPermission) return;

    final pos = await LocationHelper.getCurrentPosition(context);
    if (pos == null) return;

    final address = await LocationHelper.getAddressFromPosition(pos);
    if (address != null) {
      ref.read(fromLocationProvider.notifier).state = address;
      ref.read(fromLatLngProvider.notifier).state = pos;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel(); // cancel debounce timer
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchLocation();
    }
  }

  // Future<void> _fetchLocation() async {
  //   try {
  //     final pos = await ref.read(currentLocationProvider.future);
  //     final address = await getAddressFromPosition(pos);
  //     ref.read(fromLocationProvider.notifier).state = address;
  //     ref.read(fromLatLngProvider.notifier).state = pos;
  //   } catch (e) {
  //     if (!mounted) return;
  //
  //     ScaffoldMessenger.of(
  //       context,
  //     ).showSnackBar(SnackBar(content: Text("Please enable location: $e")));
  //
  //     final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  //     if (!serviceEnabled) {
  //       await Geolocator.openLocationSettings();
  //     }
  //   }
  // }

  Future<void> _fetchLocation() async {
    try {
      // first try cached location (fast)
      Position? cachedPos = await Geolocator.getLastKnownPosition();
      if (cachedPos != null) {
        final cachedAddress = await getAddressFromPosition(cachedPos);
        ref.read(fromLocationProvider.notifier).state = cachedAddress;
        ref.read(fromLatLngProvider.notifier).state = cachedPos;
      }

      // then get fresh location with timeout
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 5),
      );

      final address = await getAddressFromPosition(pos);
      ref.read(fromLocationProvider.notifier).state = address;
      ref.read(fromLatLngProvider.notifier).state = pos;
    } catch (e) {
      if (!mounted) return;
      // ScaffoldMessenger.of(
      //   context,
      // ).showSnackBar(SnackBar(content: Text("Please enable location: $e")));
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
      }
    }
  }

  Future<void> saveLatLng(String placeId, Position pos) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(
      placeId,
      jsonEncode({'lat': pos.latitude, 'lng': pos.longitude}),
    );
  }

  Future<Position?> getLatLng(String placeId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(placeId);
    if (jsonStr != null) {
      final data = jsonDecode(jsonStr);
      return Position(
        latitude: data['lat'],
        longitude: data['lng'],
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        headingAccuracy: 0,
        altitudeAccuracy: 0,
      );
    }
    return null;
  }

  Future<void> _loadSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? "Guest";
    });
  }

  Future<RouteInfo> getRouteInfo(Position fromPos, Position toPos) async {
    const String proxy = "https://api.allorigins.win/raw?url=";
    final targetUrl =
        "https://maps.googleapis.com/maps/api/directions/json"
        "?origin=${fromPos.latitude},${fromPos.longitude}"
        "&destination=${toPos.latitude},${toPos.longitude}"
        "&key=${Strings.googleApiKey}";

    final finalUrl = kIsWeb
        ? (proxy + Uri.encodeComponent(targetUrl))
        : targetUrl;
    final url = Uri.parse(finalUrl);

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
    final bothSelected = fromLocation.isNotEmpty && toLocation.isNotEmpty;

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
      bottomNavigationBar: ref.watch(selectedServiceProvider) == null
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  final tripStatus = ref.read(tripStatusProvider);
                  if (tripStatus.isSearching || tripStatus.tripAccepted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("You already have an active booking! 🚖"),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                  context.push('/confirm-ride');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 5,
                ),
                child: const Text(
                  "Book Ride Now",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
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
              // Active Ride Banner
              Consumer(
                builder: (context, ref, _) {
                  final tripStatus = ref.watch(tripStatusProvider);
                  if (tripStatus.isSearching || tripStatus.tripAccepted) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.deepPurple,
                            Colors.deepPurple.shade700,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.local_taxi,
                            color: Colors.white,
                            size: 30,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "You have an active ride",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  tripStatus.tripAccepted
                                      ? "Your driver is on the way!"
                                      : "Searching for your driver...",
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              if (tripStatus.tripAccepted) {
                                context.push('/tracking');
                              } else {
                                context.push('/searching');
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.deepPurple,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                            ),
                            child: const Text("Return"),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

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
                enabled:
                    !(ref.watch(tripStatusProvider).isSearching ||
                        ref.watch(tripStatusProvider).tripAccepted),
                onChanged: (val) {
                  ref.read(fromLocationProvider.notifier).state = val;
                  _routeInfo = null;
                  // Cancel previous timer if running
                  if (_debounce?.isActive ?? false) _debounce!.cancel();

                  // Start new timer
                  _debounce = Timer(const Duration(milliseconds: 500), () {
                    ref.read(placeQueryProvider.notifier).state = val;
                  });
                },

                onSuggestionTap: (suggestion) async {
                  final val = suggestion.description;
                  final placeId = suggestion.placeId;

                  ref.read(fromLocationProvider.notifier).state = val;
                  ref.read(placeQueryProvider.notifier).state = '';
                  FocusScope.of(context).unfocus();

                  // Persistent cache logic
                  Position? pos = await getLatLng(placeId);
                  if (pos != null) {
                    ref.read(fromLatLngProvider.notifier).state = pos;
                  } else {
                    pos = await getLatLngFromAddress(placeId);
                    if (pos != null) {
                      ref.read(fromLatLngProvider.notifier).state = pos;
                      await saveLatLng(placeId, pos);
                    }
                  }
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
                      enabled:
                          !(ref.watch(tripStatusProvider).isSearching ||
                              ref.watch(tripStatusProvider).tripAccepted),
                      onChanged: (val) {
                        ref.read(toLocationProvider.notifier).state = val;
                        _routeInfo = null;
                        // Cancel previous timer if running
                        if (_debounce?.isActive ?? false) _debounce!.cancel();

                        // Start new timer
                        _debounce = Timer(
                          const Duration(milliseconds: 500),
                          () {
                            ref.read(placeQueryProvider.notifier).state = val;
                          },
                        );
                      },
                      onSuggestionTap: (suggestion) async {
                        final val = suggestion.description;
                        final placeId = suggestion.placeId;

                        ref.read(toLocationProvider.notifier).state = val;
                        ref.read(placeQueryProvider.notifier).state = '';
                        FocusScope.of(context).unfocus();

                        // persistent cache logic
                        Position? pos = await getLatLng(
                          placeId,
                        ); // check local cache
                        if (pos != null) {
                          ref.read(toLatLngProvider.notifier).state = pos;
                        } else {
                          pos = await getLatLngFromAddress(placeId); // API call
                          if (pos != null) {
                            ref.read(toLatLngProvider.notifier).state = pos;
                            await saveLatLng(
                              placeId,
                              pos,
                            ); // save for next time
                          }
                        }
                      },
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(child: _buildMapButton(context, ref)),
                ],
              ),

              const SizedBox(height: 5),
              // if(ref.watch(selectedServiceProvider) == null)
              //   Text("Please Select a Service"),
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
                      final suggestion = list[index];
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
                            //
                            // final toPos = ref.read(toLatLngProvider);
                            // if (toPos != null) {
                            //   try {
                            //     final routeInfo = await getRouteInfo(
                            //       pos!,
                            //       toPos,
                            //     );
                            //
                            //     setState(() {
                            //       _routeInfo = routeInfo;
                            //
                            //       // 👉 Default select first vehicle type (or any logic you want)
                            //       final vehicleTypes =
                            //           ref.read(vehicleTypesProvider).value ??
                            //               [];
                            //       if (vehicleTypes.isNotEmpty) {
                            //         _selectedVehicleType = {
                            //           'vehTypeid':
                            //           vehicleTypes.first.vehTypeid,
                            //           'vehTypeName':
                            //           vehicleTypes.first.vehTypeName,
                            //         };
                            //       }
                            //
                            //       _selectedSubType = null;
                            //     });
                            //   } catch (e) {
                            //     ScaffoldMessenger.of(context).showSnackBar(
                            //       SnackBar(
                            //         content: Text("Distance error: $e"),
                            //       ),
                            //     );
                            //   }
                            // }
                          } else {
                            ref.read(toLocationProvider.notifier).state =
                                suggestion.description;

                            final pos = await getLatLngFromAddress(
                              suggestion.placeId,
                            );
                            if (pos != null) {
                              ref.read(toLatLngProvider.notifier).state = pos;
                              print(
                                "To Lat: ${pos.latitude}, Lng: ${pos.longitude}",
                              );

                              // // 🚀 Auto load route & subtype when To selected
                              // final fromPos = ref.read(fromLatLngProvider);
                              // if (fromPos != null) {
                              //   try {
                              //     final routeInfo = await getRouteInfo(
                              //       fromPos,
                              //       pos,
                              //     );
                              //
                              //     setState(() {
                              //       _routeInfo = routeInfo;
                              //
                              //       // 👉 Default select first vehicle type (or any logic you want)
                              //       final vehicleTypes =
                              //           ref.read(vehicleTypesProvider).value ??
                              //           [];
                              //       if (vehicleTypes.isNotEmpty) {
                              //         _selectedVehicleType = {
                              //           'vehTypeid':
                              //               vehicleTypes.first.vehTypeid,
                              //           'vehTypeName':
                              //               vehicleTypes.first.vehTypeName,
                              //         };
                              //       }
                              //
                              //       _selectedSubType = null;
                              //     });
                              //   } catch (e) {
                              //     ScaffoldMessenger.of(context).showSnackBar(
                              //       SnackBar(
                              //         content: Text("Distance error: $e"),
                              //       ),
                              //     );
                              //   }
                              // }
                            }
                          }

                          ref.read(placeQueryProvider.notifier).state = '';
                          FocusScope.of(context).unfocus();
                        },
                      );
                    },
                  );
                },
                loading: () => const Column(
                  children: [
                    CommonShimmer(width: double.infinity, height: 40),
                    SizedBox(height: 8),
                    CommonShimmer(width: double.infinity, height: 40),
                  ],
                ),
                error: (_, __) => const SizedBox(),
              ),
              const SizedBox(height: 20),

              // Only show button if both locations are selected
              if (fromLocation.isNotEmpty && toLocation.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final fromPos = ref.read(fromLatLngProvider);
                      final toPos = ref.read(toLatLngProvider);

                      if (fromPos != null && toPos != null) {
                        try {
                          final routeInfo = await getRouteInfo(fromPos, toPos);

                          setState(() {
                            _routeInfo = routeInfo;

                            // Reset subType selection
                            _selectedSubType = null;
                            ref.read(selectedServiceProvider.notifier).state =
                                null;
                            // Optional: select first vehicle type
                            final vehicleTypes =
                                ref.read(vehicleTypesProvider).value ?? [];
                            if (vehicleTypes.isNotEmpty) {
                              _selectedVehicleType = {
                                'vehTypeid': vehicleTypes.first.vehTypeid,
                                'vehTypeName': vehicleTypes.first.vehTypeName,
                              };
                            }
                          });
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Error fetching route: $e")),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      "Get Vehicle Details",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

              // Vehicle Subtypes
              if (_routeInfo != null)
                subTypesAsync().when(
                  data: (subTypes) {
                    if (subTypes.isEmpty) {
                      return Center(
                        child: Column(
                          children: [
                            SizedBox(height: 100),
                            const Text(
                              "",
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
                          "Choose a Service",
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
                                child: Column(
                                  children: [
                                    ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor:
                                            Colors.deepPurple.shade100,
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
                                    // if (isTapped) SizedBox(height: 20),
                                    // if (isTapped)
                                    //   CommonButton(
                                    //     text: 'Check Available',
                                    //     onPressed: () {
                                    //       final selectedService = ref.read(
                                    //         selectedServiceProvider,
                                    //       );
                                    //
                                    //       if (selectedService != null) {
                                    //         final subTypeId =
                                    //             selectedService['typeId'];
                                    //
                                    //         if (subTypeId != null) {
                                    //           context.push(
                                    //             '/check-available-on-map/$subTypeId',
                                    //           );
                                    //         } else {
                                    //           // பிழை ஏற்பட்டால், ஒரு செய்தியைக் காட்டலாம்
                                    //           ScaffoldMessenger.of(
                                    //             context,
                                    //           ).showSnackBar(
                                    //             const SnackBar(
                                    //               content: Text(
                                    //                 'Could not get vehicle ID. Please try again.',
                                    //               ),
                                    //             ),
                                    //           );
                                    //         }
                                    //       }
                                    //     },
                                    //     backgroundColor: Colors.green,
                                    //     foregroundColor: Colors.black,
                                    //   ),
                                    // if (isTapped) SizedBox(height: 20),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        // Book Ride Button removed from here to move to bottomNavigationBar
                      ],
                    );
                  },
                  loading: () => const ListShimmer(itemCount: 3),
                  error: (err, _) => Center(child: Text("Error: $err")),
                ),

              const SizedBox(height: 30),
              // Recent Rides
              if (!bothSelected)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 24,
                    ),
                    margin: const EdgeInsets.only(top: 30),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50, // soft background color
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.location_on_outlined,
                          color: Colors.deepPurple,
                          size: 40,
                        ),
                        SizedBox(height: 12),
                        Text(
                          "Please select\nFrom and To Destination",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ],
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
