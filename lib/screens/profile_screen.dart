import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool isDarkMode = false; // UI-only for now
  final bool isOwner = true; // Simulated role
  final String userName = "Ali Raza";
  final String assignedShop = "All Shops";

  void _logout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("Logged out")));
            },
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }

  void _changeCode() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Change Code (coming soon)")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
      appBar: AppBar(
        title: const Text("Profile & Settings"),
        backgroundColor: Colors.deepPurple,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 👤 Profile Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
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
                      userName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      isOwner ? "Owner" : "Employee",
                      style: const TextStyle(color: Colors.grey),
                    ),
                    Text(
                      "Assigned: $assignedShop",
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // 🎨 Theme Toggle
          SwitchListTile(
            value: isDarkMode,
            onChanged: (value) {
              setState(() => isDarkMode = value);
            },
            title: const Text("Dark Mode"),
            secondary: const Icon(Icons.dark_mode),
          ),

          const Divider(),

          // 🔐 Change Code (Owner only)
          if (isOwner)
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text("Change Login Code"),
              trailing: const Icon(Icons.chevron_right),
              onTap: _changeCode,
            ),

          // 🚪 Logout
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout"),
            onTap: _logout,
          ),

          const SizedBox(height: 40),

          // ℹ️ App Info
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
