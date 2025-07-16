import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';
import '../utils/logger.dart';

class EmployeeHomeScreen extends StatelessWidget {
  const EmployeeHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final user = appData.loggedInUser;

    final employeeName = user?['name'] ?? 'Employee';
    final role = user?['role'] ?? 'employee';
    final assignedShops = user?['assignedShops'] ?? [];
    final assignedShop = assignedShops.isNotEmpty
        ? assignedShops[0]
        : 'Unknown Shop';

    final myOrders = appData.orders
        .where((order) => order['employee'] == employeeName)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text("Welcome, $employeeName"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            // 👤 Header
            Text(
              "$employeeName ($role)",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text("Assigned to: $assignedShop"),
            const Divider(height: 30),

            // 📦 My Orders Summary
            Text(
              "Your Orders",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (myOrders.isEmpty)
              const Text("No orders yet.", style: TextStyle(color: Colors.grey))
            else
              ListView.separated(
                itemCount: myOrders.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final order = myOrders[index];
                  final status = order['status'] ?? 'Pending';
                  final isReceived = status == 'Received';

                  return Card(
                    elevation: 2,
                    child: ListTile(
                      leading: const Icon(
                        Icons.receipt_long,
                        color: Colors.deepPurple,
                      ),
                      title: Text("Rs. ${order['amount']}"),
                      subtitle: Text("Items: ${order['items']}"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Chip(
                            label: Text(status),
                            backgroundColor: isReceived
                                ? Colors.green.shade100
                                : Colors.orange.shade100,
                          ),
                          if (!isReceived)
                            IconButton(
                              icon: const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                              tooltip: "Mark as Received",
                              onPressed: () {
                                appData.markOrderReceived(order['id']);
                                log.info("Order marked as received");
                              },
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 30),

            // ➕ Add Order Button
            ElevatedButton.icon(
              icon: const Icon(Icons.add_box),
              label: const Text("Submit New Order"),
              onPressed: () {
                Navigator.pushNamed(context, '/add-order');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),

            const SizedBox(height: 12),

            // ➕ Add Sale Button
            ElevatedButton.icon(
              icon: const Icon(Icons.point_of_sale),
              label: const Text("Submit Sale"),
              onPressed: () {
                Navigator.pushNamed(context, '/add-sale');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),

            const SizedBox(height: 30),

            // ⚙️ Settings/Profile Access
            OutlinedButton.icon(
              icon: const Icon(Icons.person_outline),
              label: const Text("Go to Profile & Settings"),
              onPressed: () {
                Navigator.pushNamed(context, '/profile');
              },
            ),
          ],
        ),
      ),
    );
  }
}
