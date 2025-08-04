import 'package:bneeds_taxi_customer/screens/SelectLocationScreen.dart';
import 'package:bneeds_taxi_customer/screens/ServiceOptionsScreen.dart';
import 'package:go_router/go_router.dart';
import '../screens/home/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/splash_screen.dart';

final GoRouter router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/select-location',
      builder: (context, state) => const SelectLocationScreen(),
    ),
    GoRoute(
      path: '/service-options',
      builder: (context, state) => const ServiceOptionsScreen(),
    ),
  ],
);
