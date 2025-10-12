import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_data_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/login_screen.dart';
import 'add_employee_and_access_screen.dart';

// NEW
import '../widgets/auto_logout_settings.dart';
import '../services/session_timeout_service.dart';

/// Shows a confirmation dialog before logging out.
void showPlatformLogoutDialog(BuildContext context) {
  final appData = Provider.of<AppDataProvider>(context, listen: false);
  if (Platform.isIOS) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Logout?'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Logout'),
            onPressed: () {
              Navigator.of(context).pop();
              appData.logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
          ),
        ],
      ),
    );
  } else {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('Logout'),
            onPressed: () {
              Navigator.of(context).pop();
              appData.logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _passwordController;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final user =
        Provider.of<AppDataProvider>(context, listen: false).loggedInUser ?? {};
    _emailController = TextEditingController(text: user['email'] ?? '');
    _phoneController = TextEditingController(text: user['phone'] ?? '');
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    final appData = Provider.of<AppDataProvider>(context, listen: false);
    appData.updateProfile(
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      password: _passwordController.text.trim().isEmpty
          ? null
          : _passwordController.text.trim(),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    // Theme is locked to dark; keeping provider reference is harmless
    context.watch<ThemeProvider>();
    // ensure service is instantiated (no direct read needed)
    context.watch<SessionTimeoutService>();

    final user = appData.loggedInUser ?? {};
    final userName = user['name'] ?? 'Unknown';
    final userRole = (user['role'] ?? 'employee').toString().toLowerCase();

    final cs = Theme.of(context).colorScheme;
    final textColor = cs.onSurface;
    final faint = textColor.withAlpha(180);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: const Text('Profile & Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: cs.secondary,
                  child: Icon(Icons.person, size: 40, color: cs.onPrimary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userName,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor)),
                      Text(userRole.toUpperCase(), style: TextStyle(color: faint)),
                      if ((user['email'] ?? '').toString().isNotEmpty)
                        Text('Email: ${user['email']}', style: TextStyle(color: textColor)),
                      if ((user['phone'] ?? '').toString().isNotEmpty)
                        Text('Phone: ${user['phone']}', style: TextStyle(color: textColor)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // Editable Fields
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone',
              prefixIcon: Icon(Icons.phone),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Save
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Save Changes'),
              onPressed: _saveProfile,
            ),
          ),

          const SizedBox(height: 24),

          // Assign Shops to Self (Admin/Manager only)
          if (userRole == 'admin' || userRole == 'manager')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.store),
                label: const Text('Assign Shops to Myself'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddEmployeeAndAccessScreen(),
                      settings: const RouteSettings(arguments: 'assignMyself'),
                    ),
                  );
                },
              ),
            ),

          // NEW: Auto-Logout settings (visible for all roles incl. employee)
          const AutoLogoutSettingsCard(),

          const SizedBox(height: 40),
          Center(
            child: Text(
              'Version 1.0.0\nBuilt by ARS',
              textAlign: TextAlign.center,
              style: TextStyle(color: faint, fontSize: 12),
            ),
          ),

          const SizedBox(height: 24),

          // Logout
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              onPressed: () => showPlatformLogoutDialog(context),
            ),
          ),
        ],
      ),
    );
  }
}
