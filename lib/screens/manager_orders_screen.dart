import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

class ManagerOrdersScreen extends StatelessWidget {
  const ManagerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final manager = appData.loggedInUser;

    // Get shops assigned to the manager
    final assignedShops = manager?['assignedShops'] ?? [];

    // Filter only orders from assigned shops
    final managerOrders = appData.orders.where((order) {
      return assignedShops.contains(order['shop']);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Orders"),
        backgroundColor: Colors.deepPurple,
      ),
      body: managerOrders.isEmpty
          ? const Center(child: Text("No orders to manage."))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: managerOrders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final order = managerOrders[index];

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.receipt, color: Colors.deepPurple),
                          const SizedBox(width: 8),
                          Text(
                            order['orderId'] ?? "No ID",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          Chip(
                            label: Text(order['status']),
                            backgroundColor: order['status'] == 'Pending'
                                ? Colors.orange.shade100
                                : Colors.green.shade100,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text("Employee: ${order['employee']}"),
                      Text("Shop: ${order['shop']}"),
                      Text("Items: ${order['items']}"),
                      Text("Amount: Rs. ${order['amount']}"),
                      const SizedBox(height: 10),
                      if (order['status'] == 'Pending')
                        ElevatedButton.icon(
                          onPressed: () {
                            appData.forwardOrder(order['id']);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Order forwarded")),
                            );
                          },
                          icon: const Icon(Icons.send),
                          label: const Text("Forward to Admin"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
