import 'dart:async';
import 'dart:convert';
import 'package:bneeds_taxi_customer/widgets/common_main_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../providers/location_provider.dart';
import '../providers/ride_otp_provider.dart';


class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  Completer<GoogleMapController> _controller = Completer();
  final Set<Polyline> _polylines = {};
  double _progress = 0.0;
  Timer? _progressTimer;

  LatLng? _customerLatLng;
  LatLng? _driverLatLng;

  @override
  void initState() {
    super.initState();
  //  _startProgressSimulation();

    // Listen for driver location changes (StateProvider)
    // ref.listen<LatLng?>(
    //   driverLatLongProvider, // provider itself, not .notifier
    //       (_, driver) {
    //     if (driver != null) {
    //       _driverLatLng = driver;
    //       _updatePolyline();
    //     }
    //   },
    // );

    // Fetch customer location once (FutureProvider)
    _fetchCustomerLocation();
  }

  Future<void> _fetchCustomerLocation() async {
    try {
      final pos = await ref.read(currentLocationProvider.future);
      setState(() {
        _customerLatLng = LatLng(pos.latitude, pos.longitude);
      });

      // Optionally update polyline if driver location exists
      if (_driverLatLng?.latitude != 0 && _driverLatLng?.longitude != 0) {
        _updatePolyline();
      }
    } catch (e) {
      print("Failed to fetch customer location: $e");
    }
  }


  void _startProgressSimulation() {
    const duration = Duration(milliseconds: 500);
    _progressTimer = Timer.periodic(duration, (timer) {
      setState(() {
        _progress += 0.1;
        if (_progress >= 1.0) {
          _progress = 1.0;
          timer.cancel();
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) context.go('/ride-on-trip');
          });
        }
      });
    });
  }

  Future<void> _updatePolyline() async {
    if (_driverLatLng == null || _customerLatLng == null) return;

    try {
      const googleApiKey = "AIzaSyAWzUqf3Z8xvkjYV7F4gOGBBJ5d_i9HZhs"; // Replace with your key

      final points = await _getRoutePolyline(
        origin: _driverLatLng!,
        destination: _customerLatLng!,
        apiKey: googleApiKey,
      );

      setState(() {
        _polylines
          ..clear()
          ..add(
            Polyline(
              polylineId: const PolylineId('route'),
              points: points,
              width: 5,
              color: Colors.deepPurple,
            ),
          );
      });
    } catch (e) {
      print("Failed to fetch route: $e");
    }
  }

  Future<List<LatLng>> _getRoutePolyline({
    required LatLng origin,
    required LatLng destination,
    required String apiKey,
  }) async {
    try {
      // Create an instance of PolylinePoints using your enhanced class
      final polylinePoints = PolylinePoints(apiKey: apiKey);

      // Make a legacy Directions API request
      final polylineResult = await polylinePoints.getRouteBetweenCoordinates(
        request: PolylineRequest(
          origin: PointLatLng(origin.latitude, origin.longitude),
          destination: PointLatLng(destination.latitude, destination.longitude),   mode: TravelMode.driving,
        ),
      );

      if (polylineResult.points.isEmpty) return [];

      // Convert PointLatLng to LatLng
      return polylineResult.points
          .map((e) => LatLng(e.latitude, e.longitude))
          .toList();
    } catch (e) {
      print("Polyline fetch error: $e");
      return [];
    }
  }


  void showCancelDialog(BuildContext context) {
    List<String> reasons = [
      "Driver took too long",
      "Wrong address",
      "Changed my mind",
      "Booked by mistake",
    ];
    String? selectedReason;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                "Cancel Ride?",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: reasons.map((reason) {
                  return GestureDetector(
                    onTap: () => setState(() => selectedReason = reason),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: selectedReason == reason
                            ? Colors.deepPurple.withOpacity(0.1)
                            : Colors.transparent,
                        border: Border.all(
                          color: selectedReason == reason
                              ? Colors.deepPurple
                              : Colors.grey.shade300,
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedReason == reason
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: selectedReason == reason
                                ? Colors.deepPurple
                                : Colors.grey,
                          ),
                          const SizedBox(width: 10),
                          Text(reason),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Close"),
                ),
                ElevatedButton(
                  onPressed: selectedReason != null
                      ? () {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Ride cancelled: $selectedReason"),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                          context.go('/home');
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Confirm Cancel"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final otp = ref.watch(rideOtpProvider);
    final otpDigits = otp.isNotEmpty ? otp.split('') : ['-', '-', '-', '-'];

    if (_customerLatLng == null) {
      // Show loading until customer location is ready
      return const Center(child: CircularProgressIndicator());
    }

    final markers = <Marker>{};
    if (_driverLatLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: _driverLatLng!,
          infoWindow: const InfoWindow(title: 'Driver'),
        ),
      );
    }
    markers.add(
      Marker(
        markerId: const MarkerId('customer'),
        position: _customerLatLng!,
        infoWindow: const InfoWindow(title: 'You'),
      ),
    );

    return MainScaffold(
      title: ('Tracking Ride'),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: 400,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _customerLatLng!,
                  zoom: 14.5,
                ),
                onMapCreated: (controller) => _controller.complete(controller),
                markers: markers,
                polylines: _polylines,
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
              ),
            ),

            const SizedBox(height: 5),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Driver Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 30,
                          backgroundImage: AssetImage('assets/images/logo.png'),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Arun Kumar',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text('White Swift - TN 58 AB 1234'),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.star,
                                    size: 16,
                                    color: Colors.amber,
                                  ),
                                  SizedBox(width: 4),
                                  Text('4.9'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Always show OTP section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          "Tell this OTP to the driver",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: otpDigits.map((digit) {
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 20,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.deepPurple,
                                  width: 1.0,
                                ),
                              ),
                              child: Text(
                                digit,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.call),
                          label: const Text("Call Driver"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            showCancelDialog(context);
                          },
                          child: const Text("Cancel Ride"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
