import 'dart:async';
import 'dart:convert';
import 'package:bneeds_taxi_customer/models/user_profile_model.dart';
import 'package:bneeds_taxi_customer/utils/constants.dart';
import 'package:bneeds_taxi_customer/widgets/common_main_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart' hide LocationAccuracy;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/RideStorage.dart';
import '../models/cancel_model.dart';
import '../models/get_booking_model.dart';
import '../providers/booking_provider.dart';
import '../providers/location_provider.dart';
import '../providers/params/booking_params.dart';
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
  Timer? _driverLocationTimer;
  int _remainingSeconds = 120;
  Timer? _countdownTimer;
  // final LatLng _customerLatLng = const LatLng(9.9252, 78.1198);
  LatLng? _customerLatLng;

  final LatLng _driverLatLng = const LatLng(9.9391, 78.1244);
  final Set<Marker> _markers = {};
  String? _riderMobileNo;
  String? _driverName; // <-- Intha line-a add pannunga
  String? _vehicleNo;
  List<LatLng> polylineCoordinates = [];
  Position? _currentPosition;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _driverLocationTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!_isLoading) {
        print("--- Timer fired! Calling _initForTrip() now. ---");
        _initForTrip();
      }
    });
    _initializeScreen();
  }


  @override
  void dispose() {
    _countdownTimer?.cancel();
    _driverLocationTimer?.cancel();
    _progressTimer?.cancel();
    super.dispose();
  }

  // D:/Sulthan/bneeds_taxi_customer/lib/screens/tracking_screen.dart

  Future<void> _initializeScreen() async {
    if (!mounted) return;
    print("✅ [1] _initializeScreen: Starting. Setting isLoading = true.");setState(() {
      _isLoading = true;
    });

    try {
      print("✅ [2] _initializeScreen: Getting current position...");
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);
      print("✅ [3] _initializeScreen: Position received successfully. Lat: ${pos.latitude}");

      if (!mounted) return;
      _customerLatLng = LatLng(pos.latitude, pos.longitude);

      print("✅ [4] _initializeScreen: Calling _initForTrip()...");
      await _initForTrip();

      // Intha print varuthaannu paapom
      print("✅ [5] _initializeScreen: _initForTrip() finished. Now setting isLoading = false (if not already done).");

    } catch (e) {
      print("❌ ERROR in _initializeScreen: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Could not get location. Please enable location services.",
          ),
        ),
      );
      // Error vanthaalum loading-a stop panrom
      setState(() {
        _isLoading = false;
      });
    }
  }

// D:/Sulthan/bneeds_taxi_customer/lib/screens/tracking_screen.dart

  Future<void> _initForTrip() async {
    // Function start aagumbothe print panrom
    print("➡️ [A] _initForTrip: Starting...");

    final String? riderIdStr = await SharedPrefsHelper.getRiderId();
    final String? bookingIdStr = await SharedPrefsHelper.getBookingId();

    if (bookingIdStr == null || riderIdStr == null) {
      if (!mounted) return;
      // Problem-na enga-nu theriyum
      print("❌ ERROR in _initForTrip: Booking details not found in SharedPreferences.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Booking details not found.")),
      );
      // Error vanthaalum loading-a stop panrom
      setState(() => _isLoading = false);
      return;
    }

    // API call-ku munnadi print panrom
    print("➡️ [B] _initForTrip: Found bookingId: $bookingIdStr. Calling API now...");

    try {
      // --- OPTIMIZATION: PARALLEL FETCHING ---
      final results = await Future.wait([
        ref.read(
          fetchBookingDetailProvider(
            BookingParams(bookingId: int.parse("136"), riderId: int.parse("28")),
          ).future,
        ),
      ]);

      if (!mounted) return;

      // API call mudinjathum print panrom
      print("➡️ [C] _initForTrip: API call successful. Processing results...");
      final bookingDetails = results[0] as List<GetBookingDetail>?;

      if (bookingDetails == null || bookingDetails.isEmpty) {
        print("❌ ERROR in _initForTrip: API returned null or empty booking details.");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not fetch trip details.")),
        );
        // API data illanalum, loading-a stop panrom
        setState(() => _isLoading = false);
        return;
      }

      final rideData = bookingDetails.first;
      final userCurrentLocation = _customerLatLng!;

      final riderLatLngParts = rideData.riderLatLong.split(',');
      final dropLatLngParts = rideData.dropUpLatLong.split(',');

      if (riderLatLngParts.length != 2 || dropLatLngParts.length != 2) {
        print("❌ ERROR in _initForTrip: LatLng data is invalid. Parts count mismatch.");
        setState(() => _isLoading = false);
        return;
      }

      final riderLocation = LatLng(
        double.parse(riderLatLngParts[0]),
        double.parse(riderLatLngParts[1]),
      );

      final dropLocation = LatLng(
        double.parse(dropLatLngParts[0].trim()),
        double.parse(dropLatLngParts[1].trim()),
      );

      print("➡️ [D] _initForTrip: Ride data processed. Fetching route...");

      // Set details first so user can see them while route is loading
      _riderMobileNo = rideData.riderMobileNo;
      _driverName = rideData.riderName;
      _vehicleNo = rideData.vehNo;
      ref.read(rideOtpProvider.notifier).state = rideData.otp;

      final isTripStarted = rideData.tripStatus == 'P';
      final LatLng destination = isTripStarted ? dropLocation : riderLocation;

      // Route fetching-ku munnadi
      print("➡️ [E] _initForTrip: Calling getRoute()...");
      await getRoute(userCurrentLocation, destination);
      // Route fetching mudinja apram
      print("➡️ [F] _initForTrip: getRoute() finished. Calling final setState...");

      if (!mounted) return;
      setState(() {
        _markers.clear();
        _polylines.clear();

        _markers.add(
          Marker(
            markerId: const MarkerId('user_current'),
            position: userCurrentLocation,
            infoWindow: const InfoWindow(title: 'Your Location'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          ),
        );

        _markers.add(
          Marker(
            markerId: MarkerId(isTripStarted ? 'drop_location' : 'driver_location'),
            position: destination,
            infoWindow: InfoWindow(title: isTripStarted ? 'Drop Location' : 'Driver Location'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                isTripStarted ? BitmapDescriptor.hueRed : BitmapDescriptor.hueGreen),
          ),
        );

        if (polylineCoordinates.isNotEmpty) {
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('trip_route'),
              points: polylineCoordinates,
              color: Colors.deepPurple,
              width: 5,
            ),
          );
        }

        // Sariya mudincha, inga `_isLoading` false aagum
        _isLoading = false;
        print("🎉 SUCCESS! _initForTrip: Final setState called, isLoading is now false. UI should be visible.");
      });

      print("➡️ [G] _initForTrip: setState is complete. Animating camera...");
      // Camera animation-a setState-ku veliya vechikalam
      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              userCurrentLocation.latitude < destination.latitude
                  ? userCurrentLocation.latitude
                  : destination.latitude,
              userCurrentLocation.longitude < destination.longitude
                  ? userCurrentLocation.longitude
                  : destination.longitude,
            ),
            northeast: LatLng(
              userCurrentLocation.latitude > destination.latitude
                  ? userCurrentLocation.latitude
                  : destination.latitude,
              userCurrentLocation.longitude > destination.longitude
                  ? userCurrentLocation.longitude
                  : destination.longitude,
            ),
          ),
          100.0,
        ),
      );
      print("➡️ [H] _initForTrip: Camera animation finished. Function complete.");

    } catch (e) {
      // Ethavathu error vantha, inga log aagum
      print("❌❌❌ MAJOR ERROR in _initForTrip during API call or processing: $e");
      if (mounted) {
        // Error vanthaalum loading-a stop panrom
        setState(() => _isLoading = false);
      }
    }
  }


  Future<void> getRoute(LatLng start, LatLng end) async {
    // API key-a unga project constants-la irundhu eduthukonga
    const String googleApiKey = Strings.googleApiKey;

    // Constructor-la apiKey-a pass pannurom
    PolylinePoints polylinePoints = PolylinePoints(apiKey: googleApiKey);

    print(
      "getRoute called for Start: ${start.latitude},${start.longitude} and End: ${end.latitude},${end.longitude}",
    );

    // PolylineRequest object-a create panrom
    final request = PolylineRequest(
      origin: PointLatLng(start.latitude, start.longitude),
      destination: PointLatLng(end.latitude, end.longitude),
      mode: TravelMode.driving,
    );

    // Request object-a vechi call panrom
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      request: request,
    );

    if (result.points.isNotEmpty) {
      polylineCoordinates = result.points.map((point) {
        return LatLng(point.latitude, point.longitude);
      }).toList();
      print(
        "Route points fetched successfully: ${polylineCoordinates.length} points",
      );
    } else {
      print('Error getting directions: ${result.errorMessage}');
      // Fallback to a straight line if API fails
      polylineCoordinates = [start, end];
    }
  }

  // D:/Sulthan/bneeds_taxi_customer/lib/screens/tracking_screen.dart

  @override
  Widget build(BuildContext context) {
    final otp = ref.watch(rideOtpProvider);
    final otpDigits = otp.isNotEmpty ? otp.split('') : ['-', '-', '-', '-'];

    // isLoading true-va iruntha, loading mattum kaatum.
    if (_isLoading) {
      return const MainScaffold(
        title: 'Tracking Ride',
        body: Center(
          child: CircularProgressIndicator(color: Colors.deepPurple),
        ),
      );
    }

    // Data load aanathum, intha UI kaatum
    return MainScaffold(
      title: 'Tracking Ride',
      body: Stack(
        children: [
          // Map will take the full available space
          GoogleMap(
            initialCameraPosition: CameraPosition(
              // _customerLatLng null illama irukkum, because _isLoading is false
              target: _customerLatLng!,
              zoom: 14.5,
            ),
            onMapCreated: (controller) {
              if (!_controller.isCompleted) {
                _controller.complete(controller);
              }
            },
            markers: _markers,
            polylines: _polylines,
            zoomControlsEnabled: false,
            myLocationButtonEnabled:
                true, // User location button-a enable pannikalam
            myLocationEnabled: true,
          ),

          // Floating countdown timer (position correct pannirukken)
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
                "Refreshing in: ${_remainingSeconds ~/ 60}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
            ),
          ),

          // Driver details, OTP, and buttons bottom sheet-la varum
          DraggableScrollableSheet(
            initialChildSize: 0.45, // Sheet initial-a evlo height-la irukkanum
            minChildSize: 0.45, // Keela evlo varaikum izhukalam
            maxChildSize: 0.8, // Mela evlo varaikum izhukalam
            builder: (BuildContext context, ScrollController scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Driver info card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                radius: 30,
                                backgroundImage: AssetImage(
                                  'assets/images/logo.png',
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _driverName ?? "Driver Name",
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(_vehicleNo ?? "Vehicle No"),
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
                            color: Colors.white, // Intha color add pannikonga
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
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
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
                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final phone = _riderMobileNo;
                                  if (phone == null || phone.isEmpty) return;
                                  final uri = Uri.parse("tel:$phone");
                                  try {
                                    await launchUrl(uri);
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          "Error opening dialer: $e",
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.call),
                                label: const Text("Call Driver"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => showCancelDialog(context),
                                child: const Text("Cancel Ride"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
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
                ),
              );
            },
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
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text("Close"),
                ),
                ElevatedButton(
                  onPressed: selectedReason != null
                      ? () async {
                          // Close the dialog first
                          Navigator.of(dialogContext).pop();

                          final prefs = await SharedPreferences.getInstance();
                          final lastlastBookingId =
                              prefs.getString("lastlastBookingId") ?? '';

                          // Read pickup/drop values BEFORE clearing providers
                          final fromLocation =
                              ref.read(fromLocationProvider) ?? 'N/A';
                          final toLocation =
                              ref.read(toLocationProvider) ?? 'N/A';

                          // Prepare cancel model
                          final cancelModel = CancelModel(
                            decline_reason: selectedReason!,
                            lastBookingId: lastlastBookingId,
                          );

                          // Call cancel API
                          final success = await BookingRepository()
                              .cancelBooking(cancelModel);

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
                            ref.read(tripStartedProvider.notifier).state =
                                false;
                            ref.read(fromLocationProvider.notifier).state = "";
                            ref.read(toLocationProvider.notifier).state = "";

                            // // Send push notification to driver
                            // if (driverProfile != null && driverProfile!.tokenKey.isNotEmpty) {
                            //   final pushSuccess = await FirebasePushService.sendPushNotification(
                            //     fcmToken: driverProfile!.tokenKey,
                            //     title: "User Cancelled Ride",
                            //     body: "Pickup: $fromLocation\nDrop: $toLocation",
                            //     data: {
                            //       "status": "cancel_ride",
                            //       "pickup1": fromLocation,
                            //       "drop": toLocation,
                            //     },
                            //   );
                            //
                            //   if (pushSuccess) {
                            //     print("Push notification sent successfully ✅");
                            //   } else {
                            //     print("Failed to send push notification ❌");
                            //   }
                            // }

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
                                content: Text(
                                  "Failed to cancel ride. Please try again.",
                                ),
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
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Colors.deepPurple),
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
    );
  }
}
