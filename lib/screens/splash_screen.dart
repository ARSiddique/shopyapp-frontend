import 'dart:async';
import 'package:flutter/material.dart';
import 'login_screen.dart'; // Replace with actual login screen import

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // App theme color
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🖼 App Logo
            Image.asset('assets/logo/shopy_logo.png', width: 120, height: 120),
            const SizedBox(height: 20),
            // 🅰 App Name
            const Text(
              "Shopy App",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 113, 113, 113),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Retail & Shop Manager",
              style: TextStyle(
                color: Color.fromARGB(255, 113, 113, 113),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
