import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

import 'login_screen.dart';
import 'home_screen.dart';
import 'add_sale_screen.dart';
import 'shop_selection_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _hasError = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    setState(() => _hasError = false);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 800), _navigate);
  }

  Future<void> _navigate() async {
    try {
      final appData = context.read<AppDataProvider>();

      // NOTE: main.dart me AppDataProvider()..restoreSession() call ho raha.
      // yahan thoda sa wait + data warmup:
      await Future.delayed(const Duration(milliseconds: 150));
      await appData.fetchAllData();
      appData.startFirebaseListeners();

      final user = appData.loggedInUser;

      if (!mounted) return;
      if (user == null) {
        // -> Login
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }

      final role = (user['role'] ?? '').toString().toLowerCase();
      final assignedShops =
          (user['assignedShops'] as List? ?? []).map((e) => e.toString()).toList();

      Widget next;

      if (role == 'employee') {
        if (assignedShops.length == 1) {
          next = AddSaleScreen(shopName: assignedShops.first);
        } else {
          next = const ShopSelectionScreen(); // 0 ya >1 → yahan handle
        }
      } else {
        next = const HomeScreen();
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => next),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: _hasError
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Something went wrong!',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _start,
                      child: const Text('Retry'),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Hero(
                      tag: 'app-logo',
                      child: Image.asset(
                        'assets/logo/shopy_logo.png',
                        width: 120,
                        height: 120,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.store,
                          size: 120,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Shopy App',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Retail & Shop Manager',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withAlpha(
                          (0.7 * 255).round(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(
                        theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
