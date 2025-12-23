import 'package:bneeds_taxi_customer/screens/driver_searching_screen.dart';
import 'package:bneeds_taxi_customer/screens/home/HomeScreen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/RideStorage.dart';
import '../providers/ride_otp_provider.dart';
import '../screens/ride_complete_screen.dart';
import '../screens/tracking_screen.dart';
import '../utils/sharedPrefrencesHelper.dart';

/// Global navigator key (to show dialogs anywhere)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Local notifications plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Android channel
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel', // id
  'High Importance Notifications', // title
  description: 'This channel is used for important notifications.',
  importance: Importance.high,
);

/// Background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("⏰ BG Message: ${message.messageId}");
  _handleIncomingPush(message);
}

/// Call this in main()
Future<void> initFirebaseMessaging() async {
  await Firebase.initializeApp();

  // Local notifications init
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  // Android channel create
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  // Background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // iOS presentation options
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  // Foreground listener
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print("📩 Foreground: ${message.notification?.title}");
    print("🗂 Data: ${message.data}");

    _handleIncomingPush(message);

    // Still show local notification
    final notification = message.notification;
    final android = notification?.android;
    if (notification != null && android != null) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    }
  });

  // When app opened from terminated
  FirebaseMessaging.instance.getInitialMessage().then((message) {
    if (message != null) {
      print("🚀 App opened from terminated: ${message.data}");
      _handleIncomingPush(message);
    }
  });

  // When tapped on notification (background)
  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    print("👉 Opened from background: ${message.data}");
    _handleIncomingPush(message);
  });
}

/// Ask runtime notification permission
Future<void> requestNotificationPermissions() async {
  NotificationSettings settings = await FirebaseMessaging.instance
      .requestPermission(alert: true, badge: true, sound: true);
  print("🔑 Permission: ${settings.authorizationStatus}");
}

/// Handle push data
Future<void> _handleIncomingPush(
  RemoteMessage message, {
  bool openedFromTray = false,
}) async {
  print("--------> call _handleIncomingPush firebase");
  final data = message.data;
  final status = data['status'] ?? '';
  final otp = data['otp'] ?? '';
  final bookingId = data['bookingId'] ?? '';
  final riderId = data['riderId'] ?? '';

  //  await SharedPrefsHelper.setBookingId(bookingId.toString());
  //await SharedPrefsHelper.setRiderId(riderId.toString());
  print("bookingId: $bookingId");
  print("riderId: $riderId");

  final context = navigatorKey.currentContext;
  if (context == null) return;

  final container = ProviderScope.containerOf(context, listen: false);

  if (status == 'accepted') {
    print("--------> call accepted firebase");
    // // Save OTP
    // container.read(rideOtpProvider.notifier).state = otp;
    // await RideStorage.saveRideOtp(otp);
    //
    // // Save Driver LatLng
    // container.read(driverLatLongProvider.notifier).state = driverLatLong;
    // await RideStorage.saveDriverLatLong(driverLatLong);
    //
    // // Save Driver Mobile Number
    // container.read(driverMobNoProvider.notifier).state = driverMobno;
    // await RideStorage.saveDriverMobNo(driverMobno);
    //
    // container.read(dropLatLngProvider.notifier).state = dropLatLong;
    // await RideStorage.saveDropLatLong(dropLatLong);
    //
    // // Mark driver found
    // container.read(driverSearchProvider.notifier).markDriverFound();
    // await RideStorage.saveTripAccepted(true);
    _showRideAcceptedDialog(otp: otp, bookingId: bookingId, riderId: riderId);
  }

  if (status == 'start_trip') {
    // // Save OTP
    // container.read(rideOtpProvider.notifier).state = otp;
    // await RideStorage.saveRideOtp(otp);
    //
    // // Save Driver LatLng
    // container.read(driverLatLongProvider.notifier).state = driverLatLong;
    // await RideStorage.saveDriverLatLong(driverLatLong);
    //
    // // Save Drop LatLng
    // container.read(dropLatLngProvider.notifier).state = dropLatLong;
    // await RideStorage.saveDropLatLong(dropLatLong);
    //
    // // Mark trip started
    container.read(tripStartedProvider.notifier).state = true;
    // await RideStorage.saveTripStarted(true);

    // Navigate to tracking screen
    GoRouter.of(context).go('/tracking');
  }

  if (status == 'trip_completed') {
    final fareAmount = data['finalAmt'] ?? '0';
    print("---> final amount: ${fareAmount}");
    await SharedPrefsHelper.clearRiderId();
    await SharedPrefsHelper.clearBookingId();
    await SharedPrefsHelper.saveTripAccepted(false);

    // Reset providers
    container.read(rideOtpProvider.notifier).state = '';
    container.read(driverLatLongProvider.notifier).state = '';
    container.read(dropLatLngProvider.notifier).state = null;
    container.read(driverMobNoProvider.notifier).state = null;
    container.read(tripStartedProvider.notifier).state = false;

    // Navigate to RideCompleteScreen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RideCompleteScreen(fareAmount: fareAmount),
      ),
    );
  }

  if (status == 'cancel_ride') {
    showRideCancelledDialog();
  }
}

/// Show dialog when ride accepted
void _showRideAcceptedDialog({
  required String otp,
  required String bookingId,
  required String riderId,
}) {
  final context = navigatorKey.currentContext;
  if (context == null) return;

  showDialog(
    context: context,
    barrierDismissible: false, // user must tap button
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: const [
          Icon(Icons.check_circle, color: Colors.green, size: 28),
          SizedBox(width: 8),
          Text("Ride Accepted", style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Your driver has accepted your ride request.\nGet ready for pickup!",
            style: TextStyle(fontSize: 16, height: 1.4),
          ),
          const SizedBox(height: 12),
          // Text(
          //   "Your OTP: $otp", // ✅ show OTP here
          //   style: const TextStyle(
          //     fontSize: 18,
          //     fontWeight: FontWeight.bold,
          //     color: Colors.blue,
          //   ),
          // ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            print(
              "💾 Saving BookingID: $bookingId and RiderID: $riderId before navigating...",
            );
            await SharedPrefsHelper.setBookingId(bookingId.toString());
            await SharedPrefsHelper.setRiderId(riderId.toString());
            await SharedPrefsHelper.saveTripAccepted(true);
            final String? bookingIdStr = await SharedPrefsHelper.getBookingId();
            print("--------> bookingId: $bookingIdStr");
            Navigator.pop(ctx); // close dialog
            Future.microtask(() {
              GoRouter.of(context).go("/tracking"); // navigate safely
            });
          },
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.green,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text("OK"),
          ),
        ),
      ],
    ),
  );
}

void showRideCancelledDialog() {
  print('---->>>>>Dialogbox called');
  final context = navigatorKey.currentContext;
  if (context == null) return;
  showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: "Ride Cancelled",
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cancel_outlined,
                    color: Colors.redAccent,
                    size: 60,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Ride Cancelled",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "The Driver has cancelled this ride.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
                Divider(color: Colors.grey.shade300, thickness: 1),
                const SizedBox(height: 8),
                Text(
                  "Driver Cancelled You Ride",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                    ),
                    onPressed: () async {
                      Navigator.of(context).pop();

                      // Clear all saved ride data
                      await RideStorage.clearRideData();
                      await SharedPrefsHelper.saveTripAccepted(false);
                      final container = ProviderScope.containerOf(
                        context,
                        listen: false,
                      );
                      // Reset providers
                      container.read(rideOtpProvider.notifier).state = '';
                      container.read(driverLatLongProvider.notifier).state = '';
                      container.read(dropLatLngProvider.notifier).state = null;
                      container.read(driverMobNoProvider.notifier).state = null;
                      container.read(tripStartedProvider.notifier).state =
                          false;

                      // Show user feedback
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ride has been cancelled'),
                        ),
                      );

                      // Navigate to HomeScreen
                      GoRouter.of(context).go('/home');
                      Future.delayed(Duration.zero, () {
                        context.go('/home');
                      });
                    },
                    child: const Text(
                      "OK",
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: animation, child: child),
      );
    },
  );
}
