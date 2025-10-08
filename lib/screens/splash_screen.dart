import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/RideStorage.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final mobileNo = prefs.getString('mobileno');
    final isProfileCompleted = prefs.getBool('isProfileCompleted') ?? false;

    // Check if a ride is in progress or accepted
    final tripStarted = await RideStorage.getTripStarted();
    final tripAccepted = await RideStorage.getTripAccepted();

    print("📦 Mobile No: $mobileNo | ProfileCompleted: $isProfileCompleted | TripStarted: $tripStarted | TripAccepted: $tripAccepted");

    // Delay to show splash for at least 3 seconds
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    // Navigate to tracking if ride is started or accepted
    if (tripStarted || tripAccepted) {
      context.go('/tracking');
    } else if (mobileNo != null && mobileNo.isNotEmpty) {
      if (isProfileCompleted) {
        context.go('/home');
      } else {
        context.go('/profile');
      }
    } else {
      context.go('/login');
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF123456),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/logo.png', width: 180, height: 180),
              const SizedBox(height: 24),
              // Text(
              //   "Ram Meter Auto",
              //   style: TextStyle(
              //     fontSize: 32,
              //     fontWeight: FontWeight.bold,
              //     color: Colors.deepPurple.shade700,
              //     letterSpacing: 1.2,
              //   ),
              // ),
              // const SizedBox(height: 12),
              const Text(
                "Get there fast, safe and smart.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
              const SizedBox(height: 40),
              const LinearProgressIndicator(
                minHeight: 6,
                valueColor: AlwaysStoppedAnimation(Colors.deepPurple),
                backgroundColor: Colors.black12,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
