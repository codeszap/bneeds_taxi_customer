import 'package:bneeds_taxi_customer/screens/customer_support_screen.dart';
import 'package:bneeds_taxi_customer/screens/driver_searching_screen.dart';
import 'package:bneeds_taxi_customer/screens/my_rides_screen.dart';
import 'package:bneeds_taxi_customer/screens/profile_screen.dart';
import 'package:bneeds_taxi_customer/screens/ride_complete_screen.dart';
import 'package:bneeds_taxi_customer/screens/ride_ontrip_screen.dart';
import 'package:bneeds_taxi_customer/screens/select_location_screen.dart';
import 'package:bneeds_taxi_customer/screens/select_onmap_screen.dart';
import 'package:bneeds_taxi_customer/screens/service_options_screen.dart';
import 'package:bneeds_taxi_customer/screens/tracking_screen.dart';
import 'package:bneeds_taxi_customer/screens/wallet_screen.dart';
import 'package:go_router/go_router.dart';
import '../screens/check_available_onmap_screen.dart';
import '../screens/manual_start_screen.dart';
import '../screens/home/HomeScreen.dart';
import '../screens/login_screen.dart';
import '../screens/splash_screen.dart';
import '../services/firebase_service.dart';

final GoRouter router = GoRouter(
  navigatorKey: navigatorKey,
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
      path: '/manual',
      builder: (context, state) => const ManualStartScreen(),
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
      path: '/check-available-on-map/:vehSubTypeId', // <--- ':vehSubTypeId' ஐச் சேர்க்கவும்
      builder: (context, state) {
        final vehSubTypeId = state.pathParameters['vehSubTypeId']!;
        return CheckAvailableOnMapScreen(vehSubTypeId: vehSubTypeId); // <--- ID-ஐ constructor-க்கு அனுப்பவும்
      },
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
