import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bneeds_taxi_customer/services/firebase_service.dart';
import 'package:bneeds_taxi_customer/utils/remote_config_helper.dart';
import 'package:bneeds_taxi_customer/core/api_client.dart';
import 'config/routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase and Configs
  await initFirebaseMessaging();
  await requestNotificationPermissions();
  await RemoteConfigHelper.init();
  await ApiClient.init(); // Important: Initialize dynamic IP here

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: router,
      title: 'Taxi Customer',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        primaryColor: Colors.white,
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: Colors.black,
          secondary: Colors.blue,
        ),
      ),
    );
  }
}
