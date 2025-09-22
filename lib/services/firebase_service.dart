import 'package:bneeds_taxi_customer/screens/DriverSearchingScreen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/ride_otp_provider.dart';
import '../screens/RideCompleteScreen.dart';

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
          AndroidFlutterLocalNotificationsPlugin>()
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
  NotificationSettings settings =
      await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  print("🔑 Permission: ${settings.authorizationStatus}");
}

/// Handle push data
void _handleIncomingPush(RemoteMessage message, {bool openedFromTray = false}) {
  final data = message.data;
  final status = data['status'] ?? '';
  final bookingId = data['bookingId'] ?? '';
  final otp = data['otp'] ?? '';
  final driverLatLong = data['driverLatLong'] ?? '';

  if (status == 'accepted') {
    // ✅ Store OTP in Riverpod
    final context = navigatorKey.currentContext;
    if (context != null) {
      final container = ProviderScope.containerOf(context, listen: false);
      container.read(rideOtpProvider.notifier).state = otp;
      container.read(driverLatLongProvider.notifier).state = driverLatLong;

      final container2 = ProviderScope.containerOf(context, listen: false);
      container2.read(driverSearchProvider.notifier).markDriverFound();
    }

    _showRideAcceptedDialog(otp: otp);
  }
  if (status == 'completed_trip') {
    final fareAmount = data['fareAmount'] ?? '0';
    final context = navigatorKey.currentContext;
    if (context != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RideCompleteScreen(fareAmount: fareAmount),
        ),
      );
    }
  }

}


/// Show dialog when ride accepted
void _showRideAcceptedDialog({required String otp}) {
  final context = navigatorKey.currentContext;
  if (context == null) return;

  showDialog(
    context: context,
    barrierDismissible: false, // user must tap button
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: const [
          Icon(Icons.check_circle, color: Colors.green, size: 28),
          SizedBox(width: 8),
          Text(
            "Ride Accepted",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
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
          Text(
            "Your OTP: $otp", // ✅ show OTP here
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx); // close dialog
            GoRouter.of(context).go("/tracking"); // ✅ navigate to tracking
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
