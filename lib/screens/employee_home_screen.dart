import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

class EmployeeHomeScreen extends StatelessWidget {
  const EmployeeHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final user = appData.loggedInUser;

    final String employeeName = user?['name'] ?? 'Employee';
    final String assignedShop = (user?['assignedShops'] ?? []).isNotEmpty
        ? user!['assignedShops'][0]
        : 'Unknown Shop';

    final employeeOrders = appData.orders
        .where((o) => o['employee'] == employeeName)
        .toList();

    final double totalSales = employeeOrders.fold(
      0,
      (sum, order) => sum + (order['amount'] ?? 0),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text("Hi, $employeeName 👋"),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, '/employee-profile');
            },
            icon: const Icon(Icons.person),
            tooltip: "Your Profile",
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "📍 Shop: $assignedShop",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Summary Row
            Row(
              children: [
                Expanded(
                  child: _summaryCard(
                    title: "Total Orders",
                    value: employeeOrders.length.toString(),
                    icon: Icons.list_alt,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _summaryCard(
                    title: "Total Sales",
                    value: "Rs. ${totalSales.toStringAsFixed(0)}",
                    icon: Icons.attach_money,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            const Text(
              "Your Orders",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: employeeOrders.isEmpty
                  ? const Center(child: Text("No orders submitted yet."))
                  : ListView.builder(
                      itemCount: employeeOrders.length,
                      itemBuilder: (_, index) {
                        final order = employeeOrders[index];
                        final status = order['status'];
                        final isReceived = status == 'Received';

                        return Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.receipt_long,
                              color: Colors.deepPurple,
                            ),
                            title: Text(
                              "Rs. ${order['amount']} - ${order['items']}",
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Status: $status"),
                                Text("Order ID: ${order['orderId']}"),
                              ],
                            ),
                            trailing: isReceived
                                ? const Icon(Icons.check, color: Colors.green)
                                : IconButton(
                                    icon: const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    ),
                                    tooltip: "Mark as Received",
                                    onPressed: () {
                                      appData.markOrderReceived(order['id']);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Order marked as received",
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/add-order');
                    },
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text("Add Order"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/add-sale');
                    },
                    icon: const Icon(Icons.attach_money),
                    label: const Text("Add Sale"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(value, style: TextStyle(fontSize: 16, color: color)),
            ],
          ),
        ],
      ),
    );
  }
}
