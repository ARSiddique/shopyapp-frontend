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
  late TextEditingController emailController;
  late TextEditingController phoneOrPasswordController;

  @override
  void initState() {
    final user =
        Provider.of<AppDataProvider>(context, listen: false).loggedInUser ?? {};
    emailController = TextEditingController(text: user['email'] ?? '');
    phoneOrPasswordController = TextEditingController(
      text: user['role'] == 'employee'
          ? user['loginCode'] ?? ''
          : user['phone'] ?? '',
    );
    super.initState();
  }

  @override
  void dispose() {
    emailController.dispose();
    phoneOrPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final user = appData.loggedInUser ?? {};
    final role = user['role'] ?? 'employee';
    final isDarkMode = themeProvider.isDarkMode;

    final name = user['name'] ?? 'Unknown';
    final assignedShops =
        (user['assignedShops'] as List?)?.join(', ') ?? 'None';

    final isEmployee = role == 'employee';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
      appBar: AppBar(
        title: const Text("Profile & Settings"),
        backgroundColor: Colors.deepPurple,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Profile Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: const Offset(0, 3),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      role.toUpperCase(),
                      style: const TextStyle(color: Colors.grey),
                    ),
                    Text(
                      "Assigned: $assignedShops",
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // Editable Email
          TextField(
            controller: emailController,
            decoration: const InputDecoration(labelText: "Email"),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 10),

          // Editable Phone or Password based on role
          TextField(
            controller: phoneOrPasswordController,
            decoration: InputDecoration(
              labelText: isEmployee ? "Login Password" : "Phone",
            ),
            keyboardType: isEmployee ? TextInputType.text : TextInputType.phone,
          ),

          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () {
              user['email'] = emailController.text;
              if (isEmployee) {
                user['loginCode'] = phoneOrPasswordController.text;
              } else {
                user['phone'] = phoneOrPasswordController.text;
              }
              appData.notifyListeners();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("Profile updated")));
            },
            icon: const Icon(Icons.save),
            label: const Text("Save Changes"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
          ),

          const Divider(height: 40),

          // Dark Mode Toggle
          SwitchListTile(
            value: isDarkMode,
            onChanged: (value) {
              themeProvider.toggleTheme(value);
            },
            title: const Text("Dark Mode"),
            secondary: const Icon(Icons.dark_mode),
          ),

          const Divider(),

          // Optional: Admin/Owner feature
          if (role == 'admin' || role == 'owner')
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text("Change Login Code"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Change Code feature coming soon"),
                  ),
                );
              },
            ),

          // Logout
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout"),
            onTap: () {
              appData.logout();
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("Logged out")));
            },
          ),

          const SizedBox(height: 40),
          Center(
            child: Text(
              "Version 1.0.0\nBuilt with ❤️ by YourTeam",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }
}
