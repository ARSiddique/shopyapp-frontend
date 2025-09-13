import 'dart:io' show Platform;
import 'dart:developer';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_data_provider.dart';
import 'home_screen.dart';
import 'shop_selection_screen.dart';
import 'shop_actions_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // ✅ Pre-capture to avoid using BuildContext after awaits
    final navigator = Navigator.of(context);
    final appData = context.read<AppDataProvider>();

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _error = null;
    });
 if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
    setState(() {
      _isLoading = false;
      _error = 'Email and password required.';
    });
    return;
  }
    final success = await appData.loginWithEmailAndPassword(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (!mounted) return;

    if (!success) {
      setState(() {
        _isLoading = false;
      _error = 'Invalid email or password, or your account has no Firestore access.';
      });
      return;
    }

    // 🔄 Ensure fresh data + listeners
    await appData.fetchAllData();
    appData.startFirebaseListeners();

    // thora sa wait taa-ke listeners apply ho jayen
    await Future.delayed(const Duration(milliseconds: 200));

    // Data read — no context usage here
    final user = appData.loggedInUser;
    final role = (user?['role'] ?? '').toString().toLowerCase();
    final assignedShops =
        (user?['assignedShops'] as List? ?? []).map((e) => e.toString()).toList();

    log('ROLE: $role');
    log('Assigned Shops: $assignedShops');

    if (!mounted) return;
    setState(() => _isLoading = false);

    // ✅ Use pre-captured navigator (no context)
    if (role == 'employee') {
      // 🔎 Resolve a single *visible* shop from Firestore list (case-insensitive)
      final shops = appData.shops
          .where((s) => (s['isDeleted'] ?? false) != true)
          .map((s) => {
                'id': (s['id'] ?? '').toString(),
                'name': (s['name'] ?? '').toString(),
              })
          .where((s) => s['id']!.isNotEmpty && s['name']!.isNotEmpty)
          .toList();

      final assignedSet = assignedShops.map((e) => e.toLowerCase()).toSet();
      final visible = shops
          .where((s) => assignedSet.contains(s['name']!.toLowerCase()))
          .toList();

      if (visible.length == 1) {
        final only = visible.first;
        // save for rest of app
        appData.setSelectedShop(only['id']!, only['name']!);
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (_) => ShopActionsScreen(shopName: only['name']!),
          ),
        );
      } else {
        navigator.pushReplacement(
          MaterialPageRoute(builder: (_) => const ShopSelectionScreen()),
        );
      }
    } else {
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  Future<bool> _confirmExit() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => Platform.isIOS
              ? CupertinoAlertDialog(
                  title: const Text('Exit App?'),
                  content: const Text('Do you want to quit the app?'),
                  actions: [
                    CupertinoDialogAction(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.of(ctx).pop(false),
                    ),
                    CupertinoDialogAction(
                      isDestructiveAction: true,
                      child: const Text('Quit'),
                      onPressed: () => Navigator.of(ctx).pop(true),
                    ),
                  ],
                )
              : AlertDialog(
                  title: const Text('Exit App'),
                  content: const Text('Do you want to quit the app?'),
                  actions: [
                    TextButton(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.of(ctx).pop(false),
                    ),
                    TextButton(
                      child: const Text('Quit'),
                      onPressed: () => Navigator.of(ctx).pop(true),
                    ),
                  ],
                ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        final shouldExit = await _confirmExit();
        if (shouldExit) SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Hero(
                    tag: 'app-logo',
                    child: Image.asset(
                      'assets/logo/shopy_logo.png',
                      height: 120,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.store,
                        size: 120,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'Welcome to Shopy',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 30),
                  if (_error != null)
                    Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: _isLoading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: _isLoading
                          ? const SizedBox.shrink()
                          : const Text('Login'),
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
