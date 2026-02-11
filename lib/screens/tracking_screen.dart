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
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../models/RideStorage.dart';
import '../models/cancel_model.dart';
import '../models/get_booking_model.dart';
import '../providers/booking_provider.dart';
import '../providers/location_provider.dart';
import '../providers/params/booking_params.dart';
import '../providers/ride_otp_provider.dart';
import '../repositories/booking_repository.dart';
import '../utils/sharedPrefrencesHelper.dart';
import '../widgets/common_shimmer.dart';

final tripStartedProvider = StateProvider<bool>((ref) => false);

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen>
    with WidgetsBindingObserver {
  Completer<GoogleMapController> _controller = Completer();
  final Set<Polyline> _polylines = {};
  double _progress = 0.0;
  Timer? _progressTimer;
  DriverProfile? driverProfile;
  Timer? _driverLocationTimer;
  int _remainingSeconds = 120;
  static const int _refreshIntervalInSeconds = 120;
  Timer? _countdownTimer;
  // final LatLng _customerLatLng = const LatLng(9.9252, 78.1198);
  LatLng? _customerLatLng;

  final LatLng _driverLatLng = const LatLng(9.9391, 78.1244);
  final Set<Marker> _markers = {};
  String? _riderMobileNo;
  String? _driverName; // <-- Intha line-a add pannunga
  String? _vehicleNo;
  String? _pickupAddress;
  String? _destinationAddress;
  List<LatLng> polylineCoordinates = [];
  Position? _currentPosition;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = _refreshIntervalInSeconds;
    _driverLocationTimer = Timer.periodic(
      const Duration(seconds: _refreshIntervalInSeconds),
      (timer) {
        // Only run if not loading AND trip has NOT started
        if (!_isLoading && !ref.read(tripStartedProvider)) {
          print("--- Location Timer Fired! Calling _initForTrip(). ---");
          _initForTrip();
          _resetCountdown();
        } else if (ref.read(tripStartedProvider)) {
          // If trip started, we can stop the timer entirely
          timer.cancel();
          print("--- Location Timer Cancelled (Trip Started) ---");
        }
      },
    );

    _startCountdown();
    _initializeScreen();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print("📱 App Resumed: Syncing trip status...");
      _initForTrip();
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel(); // பழைய டைமர் இருந்தால் அதை ரத்து செய்யவும்
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        if (mounted) {
          setState(() {
            _remainingSeconds--;
          });
        }
      } else {
        timer.cancel(); // 0 ஆனதும் டைமரை நிறுத்தவும்
      }
    });
  }

  void _resetCountdown() {
    if (mounted) {
      setState(() {
        _remainingSeconds = _refreshIntervalInSeconds;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel(); // இதைச் சேர்க்கவும்
    _driverLocationTimer?.cancel();
    _progressTimer?.cancel();
    super.dispose();
  }

  // D:/Sulthan/bneeds_taxi_customer/lib/screens/tracking_screen.dart

  Future<void> _initializeScreen() async {
    if (!mounted) return;
    print("✅ [1] _initializeScreen: Starting. Setting isLoading = true.");
    setState(() {
      _isLoading = true;
    });

    try {
      print("✅ [2] _initializeScreen: Getting current position...");
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      print(
        "✅ [3] _initializeScreen: Position received successfully. Lat: ${pos.latitude}",
      );

      if (!mounted) return;
      _customerLatLng = LatLng(pos.latitude, pos.longitude);

      // Load trip started state early to avoid UI jump
      final started = await SharedPrefsHelper.getTripStarted();
      ref.read(tripStartedProvider.notifier).state = started;

      print("✅ [4] _initializeScreen: Calling _initForTrip()...");
      await _initForTrip();

      // Intha print varuthaannu paapom
      print(
        "✅ [5] _initializeScreen: _initForTrip() finished. Now setting isLoading = false (if not already done).",
      );
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _initForTrip() async {
    // Function start aagumbothe print panrom
    print("➡️ [A] _initForTrip: Starting...");

    final String? riderIdStr = await SharedPrefsHelper.getRiderId();
    final String? bookingIdStr = await SharedPrefsHelper.getBookingId();

    if (bookingIdStr == null || riderIdStr == null) {
      if (!mounted) return;
      // Problem-na enga-nu theriyum
      print(
        "❌ ERROR in _initForTrip: Booking details not found in SharedPreferences.",
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Booking details not found.")),
      );
      // Error vanthaalum loading-a stop panrom
      setState(() => _isLoading = false);
      return;
    }

    // API call-ku munnadi print panrom
    print(
      "➡️ [B] _initForTrip: Found bookingId: $bookingIdStr. Calling API now...",
    );

    print("-----> calling $bookingIdStr and $riderIdStr");

    try {
      // --- OPTIMIZATION: PARALLEL FETCHING ---
      final results = await Future.wait([
        ref.read(
          fetchBookingDetailProvider(
            //  BookingParams(bookingId: int.parse("206"), riderId: int.parse("3")),
            BookingParams(
              bookingId: int.parse(bookingIdStr),
              riderId: int.parse(riderIdStr),
            ),
          ).future,
        ),
      ]);

      if (!mounted) return;

      // API call mudinjathum print panrom
      print("➡️ [C] _initForTrip: API call successful. Processing results...");
      final bookingDetails = results[0] as List<GetBookingDetail>?;

      if (bookingDetails == null || bookingDetails.isEmpty) {
        print(
          "❌ ERROR in _initForTrip: API returned null or empty booking details.",
        );
        // If we can't find the ride on server, but we were tracking it, 
        // it usually means it's finished while we were away.
        if (mounted) {
          final savedFare = await SharedPrefsHelper.getFareAmount();
          print("⚠️ Ride details empty on server. Redirecting to Complete screen with fare: $savedFare");
          
          await SharedPrefsHelper.setTripCompleted(true);
          await SharedPrefsHelper.saveTripAccepted(false);
          await SharedPrefsHelper.saveTripStarted(false);
          await RideStorage.saveTripCompleted(true);
          
          context.go('/ride-complete', extra: {'fareAmount': savedFare});
        }
        return;
      }

      final rideData = bookingDetails.first;

      if (rideData.tripStatus == 'C' ||
          rideData.tripStatus == 'F' ||
          rideData.tripStatus == 'Completed') {
        print("✅ Trip Completed. Navigating to summary screen.");
        // Logic to pick the best fare amount (prioritize finalAmt if it looks valid)
        String fare = rideData.fareAmount.toString();
        if (rideData.finalAmt != null && 
            rideData.finalAmt!.isNotEmpty && 
            rideData.finalAmt != "0" && 
            rideData.finalAmt != "0.0") {
          fare = rideData.finalAmt!;
        }

        // 💾 Save completion state for app restarts
        await SharedPrefsHelper.setTripCompleted(true);
        await SharedPrefsHelper.setFareAmount(fare);
        await SharedPrefsHelper.saveTripAccepted(false); 
        await SharedPrefsHelper.setIsSearching(false);
        await SharedPrefsHelper.saveTripStarted(false);

        await RideStorage.saveTripCompleted(true);
        await RideStorage.saveFareAmount(fare);
        await RideStorage.saveTripAccepted(false);
        await RideStorage.saveTripStarted(false);

        if (mounted) {
          print("📜 Navigating to Complete Screen with Final Fare: $fare");
          context.go('/ride-complete', extra: {'fareAmount': fare});
        }
        return;
      }
      final userCurrentLocation = _customerLatLng!;

      final riderLatLngParts = rideData.riderLatLong.split(',');
      final dropLatLngParts = rideData.dropUpLatLong.split(',');

      if (riderLatLngParts.length != 2 || dropLatLngParts.length != 2) {
        print(
          "❌ ERROR in _initForTrip: LatLng data is invalid. Parts count mismatch.",
        );
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
      _pickupAddress = rideData.pickupLocation;
      _destinationAddress = rideData.dropLocation;
      ref.read(rideOtpProvider.notifier).state = rideData.otp;

      final isTripStarted =
          rideData.tripStatus == 'P' ||
          rideData.tripStatus == 'S' ||
          rideData.tripStatus == 'T';

      print(
        "🔍 [DEBUG] tripStatus: ${rideData.tripStatus}, isTripStarted: $isTripStarted",
      );

      // Update the provider state so other widgets react correctly
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // If it's already true (e.g. from push), don't set it to false unless explicitly told so by a final status
        if (isTripStarted) {
          ref.read(tripStartedProvider.notifier).state = true;
          await SharedPrefsHelper.saveTripStarted(true);
          await RideStorage.saveTripStarted(true);
        } else if (rideData.tripStatus == 'X' || rideData.tripStatus == 'Cancelled') {
          // If cancelled on server
          await SharedPrefsHelper.saveTripAccepted(false);
          await SharedPrefsHelper.setIsSearching(false);
          await SharedPrefsHelper.saveTripStarted(false);
          await RideStorage.saveTripAccepted(false);
          await RideStorage.saveTripStarted(false);
          ref.read(tripStartedProvider.notifier).state = false;
        } else {
          // If the provider is already true (likely from push), keep it true.
          // This prevents API sync from hiding the 'Started' UI if the API lags.
          if (ref.read(tripStartedProvider) == false) {
            ref.read(tripStartedProvider.notifier).state = false;
            await SharedPrefsHelper.saveTripStarted(false);
            await RideStorage.saveTripStarted(false);
          }
        }
      });

      final LatLng destination = isTripStarted ? dropLocation : riderLocation;

      // Route fetching-ku munnadi
      print("➡️ [E] _initForTrip: Calling getRoute()...");
      await getRoute(userCurrentLocation, destination);
      // Route fetching mudinja apram
      print(
        "➡️ [F] _initForTrip: getRoute() finished. Calling final setState...",
      );

      if (!mounted) return;
      setState(() {
        _markers.clear();
        _polylines.clear();

        _markers.add(
          Marker(
            markerId: const MarkerId('user_current'),
            position: userCurrentLocation,
            infoWindow: const InfoWindow(title: 'Your Location'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
          ),
        );

        _markers.add(
          Marker(
            markerId: MarkerId(
              isTripStarted ? 'drop_location' : 'driver_location',
            ),
            position: destination,
            infoWindow: InfoWindow(
              title: isTripStarted ? 'Drop Location' : 'Driver Location',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              isTripStarted
                  ? BitmapDescriptor.hueRed
                  : BitmapDescriptor.hueGreen,
            ),
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
        print(
          "🎉 SUCCESS! _initForTrip: Final setState called, isLoading is now false. UI should be visible.",
        );
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
          40.0,
        ),
      );
      print(
        "➡️ [H] _initForTrip: Camera animation finished. Function complete.",
      );
    } catch (e) {
      // Ethavathu error vantha, inga log aagum
      print(
        "❌❌❌ MAJOR ERROR in _initForTrip during API call or processing: $e",
      );
      if (mounted) {
        // Error vanthaalum loading-a stop panrom
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> getRoute(LatLng start, LatLng end) async {
    const String googleApiKey = Strings.googleApiKey;
    const String proxy = "https://api.allorigins.win/raw?url=";

    final targetUrl =
        "https://maps.googleapis.com/maps/api/directions/json"
        "?key=$googleApiKey"
        "&origin=${start.latitude},${start.longitude}"
        "&destination=${end.latitude},${end.longitude}"
        "&mode=driving";

    print(
      "getRoute called for Start: ${start.latitude},${start.longitude} and End: ${end.latitude},${end.longitude}",
    );

    try {
      final finalUrl = kIsWeb
          ? (proxy + Uri.encodeComponent(targetUrl))
          : targetUrl;
      final response = await http.get(Uri.parse(finalUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["status"] == "OK") {
          // Check if routes exist and are not empty
          if (data["routes"] != null &&
              (data["routes"] as List).isNotEmpty &&
              data["routes"][0]["overview_polyline"] != null &&
              data["routes"][0]["overview_polyline"]["points"] != null) {
            final points = data["routes"][0]["overview_polyline"]["points"];
            // Back to static call as per lint, but with safety checks around it
            final List<PointLatLng> decodedPoints =
                PolylinePoints.decodePolyline(points);

            if (decodedPoints.isNotEmpty) {
              polylineCoordinates = decodedPoints
                  .map((p) => LatLng(p.latitude, p.longitude))
                  .toList();
              print(
                "Route points fetched successfully: ${polylineCoordinates.length} points",
              );
            } else {
              print('Decoded points are empty');
              polylineCoordinates = [start, end];
            }
          } else {
            print('Invalid routes data format from Google API');
            polylineCoordinates = [start, end];
          }
        } else {
          print('Directions API error: ${data["status"]}');
          polylineCoordinates = [start, end];
        }
      } else {
        print('HTTP error: ${response.statusCode}');
        polylineCoordinates = [start, end];
      }
    } catch (e) {
      print('Error getting directions: $e');
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
        body: TrackingShimmer(),
      );
    }

    // Data load aanathum, intha UI kaatum
    return MainScaffold(
      title: 'Tracking Ride',
      body: _customerLatLng == null
          ? const Center(child: Text("Waiting for location..."))
          : Stack(
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
                  padding: EdgeInsets.only(
                    top: 120,
                    bottom: MediaQuery.of(context).size.height * 0.40,
                  ),
                ),

                // Floating countdown timer (Only show if trip NOT started)
                if (!ref.watch(tripStartedProvider))
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
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
                        "Refresh in: $_remainingSeconds s",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ),
                  ),

                // Top floating address card
                Positioned(
                  top: 16,
                  left: 16,
                  right: ref.watch(tripStartedProvider)
                      ? 16
                      : 170, // Expand if countdown is hidden
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.circle,
                              size: 10,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _pickupAddress ?? "From location",
                                style: const TextStyle(fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              height: 8,
                              child: VerticalDivider(
                                color: Colors.grey,
                                thickness: 1,
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 12,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _destinationAddress ?? "To location",
                                style: const TextStyle(fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                DraggableScrollableSheet(
                  initialChildSize: 0.45,
                  minChildSize: 0.45,
                  maxChildSize: 0.8,
                  builder:
                      (
                        BuildContext context,
                        ScrollController scrollController,
                      ) {
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
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
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
                                              if (ref.watch(
                                                tripStartedProvider,
                                              )) ...[
                                                const SizedBox(height: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        Colors.green.shade100,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                    border: Border.all(
                                                      color:
                                                          Colors.green.shade200,
                                                    ),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.location_on,
                                                        size: 14,
                                                        color: Colors.green,
                                                      ),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        "Heading to Destination",
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.green,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  // OTP or Destination card
                                  if (!ref.watch(tripStartedProvider))
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.05,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
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
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: otpDigits.map((digit) {
                                              return Container(
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                    ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 16,
                                                      horizontal: 20,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      Colors.deepPurple.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
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
                                            final phone = _riderMobileNo;
                                            if (phone == null || phone.isEmpty)
                                              return;
                                            final uri = Uri.parse("tel:$phone");
                                            try {
                                              await launchUrl(uri);
                                            } catch (e) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
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
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (!ref.watch(tripStartedProvider)) ...[
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () =>
                                                showCancelDialog(context),
                                            child: const Text("Cancel Ride"),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.redAccent,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 14,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
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
                          final String? lastlastBookingId =
                              await SharedPrefsHelper.getBookingId();

                          // Prepare cancel model
                          final cancelModel = CancelModel(
                            decline_reason: selectedReason!,
                            lastBookingId: lastlastBookingId!,
                          );

                          // Call cancel API
                          final success = await BookingRepository()
                              .cancelBooking(cancelModel);

                          if (!mounted) return;

                          if (success) {
                            // Clear ride storage and SharedPreferences
                            await RideStorage.clearRideData();
                            // await prefs.remove("lastlastBookingId");
                            await SharedPrefsHelper.clearBookingId();
                            await SharedPrefsHelper.clearLastBookingId();

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
          const CommonShimmer(width: 50, height: 50, borderRadius: 25),
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
