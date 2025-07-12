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
    final assignedShop =
        (user?['assignedShops'] != null && user!['assignedShops'].isNotEmpty)
        ? user['assignedShops'][0]
        : 'Unknown Shop';

    final employeeOrders = appData.orders
        .where((order) => order['employee'] == employeeName)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text("Welcome, $employeeName"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Your Orders at $assignedShop",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            if (employeeOrders.isEmpty)
              const Text(
                "No orders submitted yet.",
                style: TextStyle(color: Colors.grey),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: employeeOrders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final order = employeeOrders[index];
                    final status = order['status'];
                    final isReceived = status == 'Received';

                    return Card(
                      elevation: 3,
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
              ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text("Submit New Order"),
                onPressed: () {
                  Navigator.pushNamed(context, '/add-order');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
