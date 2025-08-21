import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  print("📦 Mobile No: $mobileNo | ProfileCompleted: $isProfileCompleted");

  // Delay to show splash for at least 3 seconds
  await Future.delayed(const Duration(seconds: 3));

  if (!mounted) return; // Ensure widget is still in tree

  if (mobileNo != null && mobileNo.isNotEmpty) {
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
      backgroundColor: Colors.deepPurple.shade50,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/logo.png', width: 180, height: 180),
              const SizedBox(height: 24),
              Text(
                "RideX",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple.shade700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Get there fast, safe and smart.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Colors.deepPurple),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
