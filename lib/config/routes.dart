import 'package:bneeds_taxi_customer/screens/CustomerSupportScreen.dart';
import 'package:bneeds_taxi_customer/screens/DriverSearchingScreen.dart';
import 'package:bneeds_taxi_customer/screens/MyRidesScreen.dart';
import 'package:bneeds_taxi_customer/screens/ProfileScreen.dart';
import 'package:bneeds_taxi_customer/screens/RideCompleteScreen.dart';
import 'package:bneeds_taxi_customer/screens/RideOnTripScreen.dart';
import 'package:bneeds_taxi_customer/screens/SelectLocationScreen.dart';
import 'package:bneeds_taxi_customer/screens/SelectOnMapScreen.dart';
import 'package:bneeds_taxi_customer/screens/ServiceOptionsScreen.dart';
import 'package:bneeds_taxi_customer/screens/TrackingScreen.dart';
import 'package:bneeds_taxi_customer/screens/WalletScreen.dart';
import 'package:go_router/go_router.dart';
import '../screens/home/customize_home.dart';
import '../screens/login_screen.dart';
import '../screens/splash_screen.dart';
import '../services/firebase_service.dart'; // 👈 navigatorKey is here

final GoRouter router = GoRouter(
  navigatorKey: navigatorKey, // 👈 put it here, not inside routes
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/select-location',
      builder: (context, state) {
        final vehTypeId = state.extra as String;
        return SelectLocationScreen(vehTypeId: vehTypeId);
      },
    ),
    GoRoute(
      path: '/service-options',
      builder: (context, state) {
        final extra = state.extra;
        if (extra is! Map<String, dynamic>) {
          throw Exception('Expected a Map<String, dynamic> in state.extra');
        }

        final vehTypeId = extra['vehTypeId'] as String;
        final totalKms = extra['totalKms'].toString();
        final estTime = extra['estTime'].toString();

        return ServiceOptionsScreen(
          vehTypeId: vehTypeId,
          totalKms: totalKms,
          estTime: estTime,
        );
      },
    ),
    GoRoute(
      path: '/searching',
      builder: (context, state) => const DriverSearchingScreen(),
    ),
    GoRoute(
      path: '/tracking',
      builder: (context, state) => const TrackingScreen(),
    ),
    GoRoute(
      path: '/wallet',
      builder: (context, state) => const WalletScreen(),
    ),
    GoRoute(
      path: '/select-on-map',
      builder: (context, state) => const SelectOnMapScreen(),
    ),
    GoRoute(
      path: '/ride-on-trip',
      builder: (context, state) => const RideOnTripScreen(),
    ),
    GoRoute(
      path: '/ride-complete',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final fareAmount = extra['fareAmount'] ?? '0';
        return RideCompleteScreen(fareAmount: fareAmount);
      },
    ),

    GoRoute(
      path: '/customer-support',
      builder: (context, state) => const CustomerSupportScreen(),
    ),
    GoRoute(
      path: '/my-rides',
      builder: (context, state) => const MyRidesScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
  ],
);
