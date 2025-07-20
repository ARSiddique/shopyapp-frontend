import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/app_data_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _passwordController;
  bool _obscurePassword = false; // show password by default

  @override
  void initState() {
    super.initState();
    final user =
        Provider.of<AppDataProvider>(context, listen: false).loggedInUser ?? {};
    _emailController = TextEditingController(text: user['email'] ?? '');
    _phoneController = TextEditingController(text: user['phone'] ?? '');
    _passwordController = TextEditingController(text: user['password'] ?? '');
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
      password: _passwordController.text,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Profile updated successfully")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final user = appData.loggedInUser ?? {};
    final userName = user['name'] ?? "Unknown";
    final userRole = (user['role'] ?? "employee").toString().toLowerCase();

    // dynamic text color
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    // safe cast for assignedShops
    final rawAssigned = user['assignedShops'] ?? <dynamic>[];
    final assignedList = List<String>.from(rawAssigned);
    final assignedShops = assignedList.join(', ');

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: Text(
          "Profile & Settings",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ——— Header ———
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.deepPurple,
                  child: Icon(Icons.person, size: 40, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),

                      // ROLE
                      Text(
                        userRole.toUpperCase(),
                        style: TextStyle(
                          color: textColor.withAlpha((0.7 * 255).round()),
                        ),
                      ),

                      // EMAIL & PHONE (if provided)
                      if ((user['email'] ?? '').isNotEmpty)
                        Text(
                          "Email: ${user['email']}",
                          style: TextStyle(color: textColor),
                        ),
                      if ((user['phone'] ?? '').isNotEmpty)
                        Text(
                          "Phone: ${user['phone']}",
                          style: TextStyle(color: textColor),
                        ),

                      // ASSIGNED shops only for employees
                      if (userRole == 'employee')
                        Text(
                          "Assigned: ${assignedShops.isEmpty ? 'None' : assignedShops}",
                          style: TextStyle(fontSize: 12, color: textColor),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // ——— Editable Fields ———
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: "Email",
              border: const OutlineInputBorder(),
              prefixIcon: Icon(Icons.email, color: textColor),
            ),
            style: TextStyle(color: textColor),
            keyboardType: TextInputType.emailAddress,
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _phoneController,
            decoration: InputDecoration(
              labelText: "Phone",
              border: const OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone, color: textColor),
            ),
            style: TextStyle(color: textColor),
            keyboardType: TextInputType.phone,
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: "Password",
              border: const OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock, color: textColor),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: textColor,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            style: TextStyle(color: textColor),
          ),

          const SizedBox(height: 24),

          // ——— Save Button ———
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.save, color: Colors.white),
              label: const Text(
                "Save Changes",
                style: TextStyle(color: Colors.white),
              ),
              onPressed: _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                // foregroundColor: Colors.white, 
              ),
            ),
          ),

          const SizedBox(height: 40),

          // ——— Version ———
          Center(
            child: Text(
              "Version 1.0.0\nBuilt by ARS",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor.withAlpha((0.6 * 255).round()),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
