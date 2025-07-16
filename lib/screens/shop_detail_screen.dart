import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

class ShopDetailScreen extends StatelessWidget {
  final String shopName;

  const ShopDetailScreen({super.key, required this.shopName});

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final user = appData.loggedInUser ?? {};
    final role = user['role'] ?? 'employee';

    final shop = appData.shops.firstWhere(
      (s) => s['name'] == shopName,
      orElse: () => {},
    );

    final employeeNames = List<String>.from(shop['employees'] ?? []);
    final employees = employeeNames
        .map((name) => appData.getEmployeeByName(name))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(shopName),
        backgroundColor: Colors.deepPurple,
        actions: [
          if (role == 'admin')
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: () {
                appData.deleteShopByName(shopName);
                Navigator.pop(context);
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: employees.isEmpty
            ? const Center(child: Text("No employees assigned yet."))
            : ListView.builder(
                itemCount: employees.length,
                itemBuilder: (_, index) {
                  final emp = employees[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(emp['name'] ?? 'Unknown'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (emp['email'] != null) Text("📧 ${emp['email']}"),
                          if (emp['phone'] != null) Text("📱 ${emp['phone']}"),
                          if (emp['role'] != null) Text("🎓 ${emp['role']}"),
                          if (emp['assignedShops'] != null)
                            Text("🏬 ${emp['assignedShops'].join(', ')}"),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
      ),
    );
  }
}
