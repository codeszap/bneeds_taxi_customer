import 'package:bneeds_taxi_customer/widgets/common_main_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:location/location.dart' as loc;

import '../models/user_profile_model.dart';
import '../repositories/profile_repository.dart';

class CheckAvailableOnMapScreen extends StatefulWidget {
  final String vehSubTypeId;

  const CheckAvailableOnMapScreen({
    super.key,
    required this.vehSubTypeId,
  });

  @override
  State<CheckAvailableOnMapScreen> createState() =>
      _CheckAvailableOnMapScreenState();
}

class _CheckAvailableOnMapScreenState extends State<CheckAvailableOnMapScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  String? _address;
  bool _loading = true; // துவக்கத்தில் loading-ஐ true என அமைக்கவும்

  final loc.Location _location = loc.Location();
  List<DriverProfile> _drivers = [];
  final Set<Marker> _markers = {}; // எல்லா மார்க்கர்களையும் இங்கே சேமிக்கவும்

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _initializeLocation();

    if (_currentLocation != null) {
      await _fetchNearbyDrivers();
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }



  // ... inside _CheckAvailableOnMapScreenState class

  Future<void> _fetchNearbyDrivers() async {
    print("Fetching drivers for SubType ID: ${widget.vehSubTypeId}");
    try {
      final newDrivers = await ProfileRepository().getDriverNearby(
        vehSubTypeId: widget.vehSubTypeId,
        riderStatus: "OL",
      );

      // <<< START: NEW CODE TO HANDLE NO DRIVERS >>>
      // ஓட்டுநர்கள் யாரும் இல்லை என்றால், பாப்-அப் காண்பிக்கவும்
      if (newDrivers.isEmpty && mounted) {
        showDialog(
          context: context,
          barrierDismissible: false, // வெளியே தட்டினால் மூடக்கூடாது
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text("No Drivers Found"),
              content: const Text("Sorry, there are no drivers available near you at the moment."),
              actions: <Widget>[
                TextButton(
                  child: const Text("OK"),
                  onPressed: () {
                    // பாப்-அப்பை மூடி, முந்தைய திரைக்கு (Home Screen) செல்லவும்
                    Navigator.of(dialogContext).pop(); // Dialog ஐ மூடு
                    Navigator.of(context).pop();      // Map Screen ஐ மூடு
                  },
                ),
              ],
            );
          },
        );
        // பாப்-அப் காண்பித்த பிறகு, இந்த செயல்பாட்டை இங்கேயே நிறுத்திக் கொள்ளவும்.
        return;
      }
      // <<< END: NEW CODE TO HANDLE NO DRIVERS >>>

      final newDriverMarkers = newDrivers.map((driver) {
        final latLongParts = driver.fromLatLong.split(',');

        if (latLongParts.length == 2) {
          final lat = double.tryParse(latLongParts[0]);
          final lng = double.tryParse(latLongParts[1]);

          if (lat != null && lng != null) {
            return Marker(
              markerId: MarkerId('driver_${driver.riderId}'),
              position: LatLng(lat, lng),
              infoWindow: InfoWindow(title: driver.riderName),
              icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            );
          }
        }
        return null;
      }).whereType<Marker>().toSet();

      if (mounted) {
        setState(() {
          _drivers = newDrivers;
          _markers.removeWhere((marker) => marker.markerId.value != "current_location");
          _markers.addAll(newDriverMarkers);

          if (_markers.length > 1) {
            final bounds = _boundsFromMarkers(_markers);
            _mapController?.animateCamera(
              CameraUpdate.newLatLngBounds(bounds, 50.0),
            );
          } else if (_markers.length == 1) {
            _mapController?.animateCamera(
              CameraUpdate.newLatLngZoom(_markers.first.position, 15.0),
            );
          }
        });
      }
    } catch (e) {
      print("Error fetching nearby drivers: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to find nearby drivers: $e')),
        );
      }
    }
  }

// ... inside _CheckAvailableOnMapScreenState class

// ... after the _fetchNearbyDrivers() method ends

  // <<< START: ADD THIS MISSING METHOD >>>
  LatLngBounds _boundsFromMarkers(Set<Marker> markers) {
    assert(markers.isNotEmpty);
    double? minLat, maxLat, minLng, maxLng;

    for (final marker in markers) {
      final lat = marker.position.latitude;
      final lng = marker.position.longitude;

      if (minLat == null || lat < minLat) {
        minLat = lat;
      }
      if (maxLat == null || lat > maxLat) {
        maxLat = lat;
      }
      if (minLng == null || lng < minLng) {
        minLng = lng;
      }
      if (maxLng == null || lng > maxLng) {
        maxLng = lng;
      }
    }
    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }



  Future<void> _initializeLocation() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        if (mounted) setState(() => _loading = false);
        return;
      }
    }

    loc.PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == loc.PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != loc.PermissionStatus.granted) {
        if (mounted) setState(() => _loading = false);
        return;
      }
    }

    try {
      final currentLoc = await _location.getLocation();
      final userLatLng = LatLng(currentLoc.latitude!, currentLoc.longitude!);

      if (mounted) {
        setState(() {
          _currentLocation = userLatLng;
          // பயனரின் மார்க்கரை _markers செட்டில் சேர்க்கவும்
          _markers.add(
            Marker(
              markerId: const MarkerId("current_location"),
              position: _currentLocation!,
              infoWindow: const InfoWindow(title: "Your Location"),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
            ),
          );
        });
      }

      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(userLatLng, 15));
      await _getAddressFromLatLng(userLatLng);
    } catch (e) {
      print("Error getting location: $e");
      if (mounted) {
        setState(() {
          _address = "Failed to get location";
        });
      }
    }
  }

  // முகவரியைப் பெற
  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        if (mounted) {
          setState(() {
            _address = "${p.name}, ${p.subLocality}, ${p.locality}";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _address = "Failed to fetch address");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      title: "Check Availabilty on Map",
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(9.9252, 78.1198), // Default to Madurai
              zoom: 12,
            ),
            myLocationEnabled: false, // நாம் சொந்தமாக மார்க்கர் வைப்பதால் இதை false செய்யலாம்
            myLocationButtonEnabled: true,
            onMapCreated: (controller) {
              _mapController = controller;
            },
            markers: _markers, // இங்கே எல்லா மார்க்கர்களையும் காண்பிக்கவும்
          ),
          // முகவரியைக் காண்பிக்க
          if (_address != null)
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    _address!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
          // Loading Indicator-ஐ மையத்தில் காட்டவும்
          if (_loading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
