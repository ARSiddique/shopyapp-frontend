import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

class AdminOrdersScreen extends StatelessWidget {
  const AdminOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final orders = appData.orders;

    return Scaffold(
      appBar: AppBar(
        title: const Text("All Orders"),
        backgroundColor: Colors.deepPurple,
      ),
      body: orders.isEmpty
          ? const Center(child: Text("No orders found."))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final order = orders[index];
                return Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.receipt,
                      color: Colors.deepPurple,
                    ),
                    title: Text(
                      "Rs. ${order['amount']} - ${order['employee']}",
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Shop: ${order['shop']}"),
                        Text("Status: ${order['status']}"),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        appData.deleteOrder(order['id']);
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
