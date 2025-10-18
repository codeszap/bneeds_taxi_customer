import 'dart:async';
import 'dart:convert';
import 'package:bneeds_taxi_customer/models/user_profile_model.dart';
import 'package:bneeds_taxi_customer/utils/constants.dart';
import 'package:bneeds_taxi_customer/widgets/common_main_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/RideStorage.dart';
import '../models/cancel_model.dart';
import '../providers/location_provider.dart';
import '../providers/ride_otp_provider.dart';
import '../repositories/booking_repository.dart';
import '../repositories/profile_repository.dart';
import '../services/FirebasePushService.dart';
import '../utils/sharedPrefrencesHelper.dart';

final tripStartedProvider = StateProvider<bool>((ref) => false);

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
  DriverProfile? driverProfile;
  LatLng? _customerLatLng;
  LatLng? _driverLatLng;
  Timer? _driverLocationTimer;
  int _remainingSeconds = 120; // default 2 mins = 120 seconds
  Timer? _countdownTimer;

  @override
  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _loadRemainingTime();
    await _loadSavedRideInfo();
    await _fetchCustomerLocation();
    await fetchDriverProfile();
    _startDriverLocationPolling();
  }

  Future<void> _loadRemainingTime() async {
    final savedTime = await SharedPrefsHelper.getDriverTimer();
    if (!mounted) return;
    setState(() {
      _remainingSeconds = savedTime;
    });
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        print("⏰ Timer ended");
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _saveRemainingTime();
    _driverLocationTimer?.cancel();
    _progressTimer?.cancel();
    super.dispose();
  }

  Future<void> _saveRemainingTime() async {
    await SharedPrefsHelper.setDriverTimer(_remainingSeconds);
  }

  Future<void> _loadSavedRideInfo() async {
    final savedDriverLatLong = await RideStorage.getDriverLatLong();
    final savedDropLatLong = await RideStorage.getDropLatLong();
    final savedDriverMobNo = await RideStorage.getDriverMobNo();
    final savedTripStarted = await RideStorage.getTripStarted();
    final savedOtp = await RideStorage.getRideOtp();

    // Update Riverpod providers safely
    if (savedOtp != null) {
      ref.read(rideOtpProvider.notifier).state = savedOtp;
    }

    if (savedDriverLatLong != null && savedDriverLatLong.isNotEmpty) {
      ref.read(driverLatLongProvider.notifier).state = savedDriverLatLong;
    }

    if (savedDropLatLong != null && savedDropLatLong.isNotEmpty) {
      ref.read(dropLatLngProvider.notifier).state = savedDropLatLong;
    }

    if (savedDriverMobNo != null && savedDriverMobNo.isNotEmpty) {
      ref.read(driverMobNoProvider.notifier).state = savedDriverMobNo;
    }

    if (savedTripStarted != null) {
      ref.read(tripStartedProvider.notifier).state = savedTripStarted;
    }
  }



  void _startDriverLocationPolling() {
    _fetchDriverLocation();
    _driverLocationTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _fetchDriverLocation();
    });
  //  _fetchDriverLocation(); // initial
  }

  Future<void> _fetchDriverLocation() async {
    try {
      final driverMobNo = ref.read(driverMobNoProvider) ?? "";
      if (driverMobNo.isEmpty) return;

      final driverList = await ProfileRepository().getDriverDetail(
        mobileno: driverMobNo,
      );

      if (driverList.isNotEmpty) {
        final driver = driverList[0];

        if (driver.fromLatLong != null && driver.fromLatLong!.isNotEmpty) {
          final latLngParts = driver.fromLatLong!.split(',');
          if (latLngParts.length == 2) {
            final lat = double.tryParse(latLngParts[0].trim());
            final lng = double.tryParse(latLngParts[1].trim());

            if (lat != null && lng != null) {
              setState(() {
                _driverLatLng = LatLng(lat, lng);
                _remainingSeconds = 120; // Reset timer to 2 minutes
              });
              _saveRemainingTime();
              _startCountdown();

              _updatePolyline();
            }
          }
        }
      }
    } catch (e) {
      print("❌ Error fetching driver location: $e");
    }
  }


  Future<void> _fetchCustomerLocation() async {
    try {
      final pos = await ref.read(currentLocationProvider.future);
      setState(() {
        _customerLatLng = LatLng(pos.latitude, pos.longitude);
       // _customerLatLng = LatLng(9.9155706,78.1106788);
      });

      if (_driverLatLng != null) {
        _updatePolyline();
      }
    } catch (e) {
      print("Failed to fetch customer location: $e");
    }
  }

  Future<void> fetchDriverProfile() async {
    final driverMobNo = ref.read(driverMobNoProvider) ?? "";
    if (driverMobNo.isEmpty) return;

    final profileList = await ProfileRepository().getDriverDetail(
      mobileno: driverMobNo,
    );

    if (profileList.isNotEmpty) {
      if (!mounted) return; // safety check
      setState(() {
        driverProfile = profileList[0];
      });
    }
  }

  Future<void> _updatePolyline() async {
    if (_driverLatLng == null || _customerLatLng == null) return;
    if (!_controller.isCompleted) return;
    final controller = await _controller.future;

    try {
      //const googleApiKey = "AIzaSyAWzUqf3Z8xvkjYV7F4gOGBBJ5d_i9HZhs";
      List<LatLng> points = [];
      final tripStarted = ref.read(tripStartedProvider);

      LatLng origin = _driverLatLng!;
      LatLng destination = _customerLatLng!;

      if (!tripStarted) {
        // Driver → Pickup
        points = await _getRoutePolyline(
          origin: origin,
          destination: destination,
          apiKey: Strings.googleApiKey,
        );
      } else {
        // Pickup → Drop
        final dropLatLngStr = ref.read(dropLatLngProvider);
        if (dropLatLngStr != null && dropLatLngStr.isNotEmpty) {
          final latLngList = dropLatLngStr.replaceAll(RegExp(r'[^\d.,-]'), '').split(',');
          if (latLngList.length == 2) {
            origin = _customerLatLng!;
            destination = LatLng(double.parse(latLngList[0]), double.parse(latLngList[1]));
            points = await _getRoutePolyline(
              origin: origin,
              destination: destination,
              apiKey: Strings.googleApiKey,
            );
          }
        }
      }

      setState(() {
        _polylines
          ..clear()
          ..add(Polyline(
            polylineId: const PolylineId('route'),
            points: points,
            width: 5,
            color: Colors.deepPurple,
          ));
      });

      // ✅ Center camera properly
      final markersList = [origin, destination];
      final bounds = _createBoundsFromLatLngList(markersList);
      controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));

    } catch (e) {
      print("Failed to fetch route: $e");
    }
  }

  LatLngBounds _createBoundsFromLatLngList(List<LatLng> list) {
    double? x0, x1, y0, y1;
    for (LatLng latLng in list) {
      if (x0 == null) {
        x0 = x1 = latLng.latitude;
        y0 = y1 = latLng.longitude;
      } else {
        if (latLng.latitude > x1!) x1 = latLng.latitude;
        if (latLng.latitude < x0) x0 = latLng.latitude;
        if (latLng.longitude > y1!) y1 = latLng.longitude;
        if (latLng.longitude < y0!) y0 = latLng.longitude;
      }
    }
    return LatLngBounds(southwest: LatLng(x0!, y0!), northeast: LatLng(x1!, y1!));
  }


  Future<List<LatLng>> _getRoutePolyline({
    required LatLng origin,
    required LatLng destination,
    required String apiKey,
  }) async {
    try {
      final polylinePoints = PolylinePoints(apiKey: apiKey);

      final polylineResult = await polylinePoints.getRouteBetweenCoordinates(
        request: PolylineRequest(
          origin: PointLatLng(origin.latitude, origin.longitude),
          destination: PointLatLng(destination.latitude, destination.longitude),
          mode: TravelMode.driving,
        ),
      );

      if (polylineResult.points.isEmpty) return [];

      return polylineResult.points
          .map((e) => LatLng(e.latitude, e.longitude))
          .toList();
    } catch (e) {
      print("Polyline fetch error: $e");
      return [];
    }
  }

  Future<void> _handleRefresh() async {
    try {
      // 1. Fetch latest driver location
      await _fetchDriverLocation();

      // 2. Fetch customer location (optional, if it can change)
      await _fetchCustomerLocation();

      // 3. Fetch driver profile
      await fetchDriverProfile();

      // 4. Reset countdown timer
      setState(() {
        _remainingSeconds = 120;
      });
      _saveRemainingTime();
      _startCountdown();
    } catch (e) {
      print("Refresh failed: $e");
    }
  }


  @override
  Widget build(BuildContext context) {
    final otp = ref.watch(rideOtpProvider);
    final otpDigits = otp.isNotEmpty ? otp.split('') : ['-', '-', '-', '-'];
    final tripStarted = ref.watch(tripStartedProvider);

    if (_customerLatLng == null) {
      return const FullScreenLoader(message: "Fetching your location...");
    }


    final markers = <Marker>{};

    if (!tripStarted) {
      // Before trip → Driver + Pickup
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
          markerId: const MarkerId('pickup'),
          position: _customerLatLng!,
          infoWindow: const InfoWindow(title: 'Pickup'),
        ),
      );
    } else {
      // After trip → Pickup + Drop
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: _customerLatLng!,
          infoWindow: const InfoWindow(title: 'Pickup'),
        ),
      );

      final dropLatLngStr = ref.watch(dropLatLngProvider);
      if (dropLatLngStr != null && dropLatLngStr.isNotEmpty) {
        final latLngList = dropLatLngStr
            .replaceAll(RegExp(r'[^\d.,-]'), '')
            .split(',');
        if (latLngList.length == 2) {
          final dropLatLng = LatLng(
            double.parse(latLngList[0]),
            double.parse(latLngList[1]),
          );
          markers.add(
            Marker(
              markerId: const MarkerId('drop'),
              position: dropLatLng,
              infoWindow: const InfoWindow(title: 'Drop Location'),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen,
              ),
            ),
          );
        }
      }
    }

    return MainScaffold(
      title: 'Tracking Ride',
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _handleRefresh,
            child: SingleChildScrollView(
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
                        // Driver info card
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
                                  children: [
                                    Text(
                                      driverProfile?.riderName ?? "No data",
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(driverProfile?.vehNo ?? "No data"),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // OTP card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
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
                                onPressed: () async {
                                //  final phone = "8870602962";
                                  final phone = driverProfile?.mobileNo;
                                  final uri = Uri.parse("tel:$phone");
                                  try {
                                    await launchUrl(uri, mode: LaunchMode.platformDefault);
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Error opening dialer: $e")),
                                    );
                                  }
                                },
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
                          //  if (!tripStarted)
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => showCancelDialog(context),
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
          ),
          // Floating countdown timer
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                "Location Refresh in: ${_remainingSeconds ~/ 60}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void showCancelDialog(BuildContext outerContext) {
    List<String> reasons = [
      "Driver took too long",
      "Wrong address",
      "Changed my mind",
      "Booked by mistake",
    ];
    String? selectedReason;

    showDialog(
      context: outerContext,
      barrierDismissible: false,
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text("Close"),
                ),
                ElevatedButton(
                  onPressed: selectedReason != null
                      ? () async {
                    // Close the dialog first
                    Navigator.of(dialogContext).pop();

                    final prefs = await SharedPreferences.getInstance();
                    final lastlastBookingId = prefs.getString("lastlastBookingId") ?? '';

                    // Read pickup/drop values BEFORE clearing providers
                    final fromLocation = ref.read(fromLocationProvider) ?? 'N/A';
                    final toLocation = ref.read(toLocationProvider) ?? 'N/A';

                    // Prepare cancel model
                    final cancelModel = CancelModel(
                      decline_reason: selectedReason!,
                      lastBookingId: lastlastBookingId,
                    );

                    // Call cancel API
                    final success = await BookingRepository().cancelBooking(cancelModel);

                    if (!mounted) return;

                    if (success) {
                      // Clear ride storage and SharedPreferences
                      await RideStorage.clearRideData();
                      await prefs.remove("lastlastBookingId");

                      // Clear all related Riverpod providers
                      ref.read(rideOtpProvider.notifier).state = '';
                      ref.read(driverLatLongProvider.notifier).state = '';
                      ref.read(dropLatLngProvider.notifier).state = null;
                      ref.read(driverMobNoProvider.notifier).state = null;
                      ref.read(tripStartedProvider.notifier).state = false;
                      ref.read(fromLocationProvider.notifier).state = "";
                      ref.read(toLocationProvider.notifier).state = "";

                      // Send push notification to driver
                      if (driverProfile != null && driverProfile!.tokenKey.isNotEmpty) {
                        final pushSuccess = await FirebasePushService.sendPushNotification(
                          fcmToken: driverProfile!.tokenKey,
                          title: "User Cancelled Ride",
                          body: "Pickup: $fromLocation\nDrop: $toLocation",
                          data: {
                            "status": "cancel_ride",
                            "pickup1": fromLocation,
                            "drop": toLocation,
                          },
                        );

                        if (pushSuccess) {
                          print("Push notification sent successfully ✅");
                        } else {
                          print("Failed to send push notification ❌");
                        }
                      }

                      // Show success message
                      ScaffoldMessenger.of(outerContext).showSnackBar(
                        const SnackBar(
                          content: Text("Ride cancelled successfully ✅"),
                          backgroundColor: Colors.green,
                        ),
                      );

                      // Navigate to home screen
                      GoRouter.of(outerContext).go('/home');
                    } else {
                      // Show failure message
                      ScaffoldMessenger.of(outerContext).showSnackBar(
                        const SnackBar(
                          content: Text("Failed to cancel ride. Please try again."),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
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



}

class FullScreenLoader extends StatelessWidget {
  final String message;
  const FullScreenLoader({this.message = "Loading...", super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: Colors.deepPurple,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.deepPurple,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
