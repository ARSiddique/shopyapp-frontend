import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orders = Provider.of<AppDataProvider>(context).orders;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Orders"),
        backgroundColor: Colors.deepPurple,
      ),
      body: orders.isEmpty
          ? const Center(child: Text("No orders yet."))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final order = orders[index];

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
                      // Top Row: Order ID and Date
                      Row(
                        children: [
                          const Icon(Icons.receipt, color: Colors.deepPurple),
                          const SizedBox(width: 8),
                          Text(
                            "Order ID: ${order['id']}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            order['date'],
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Shop + Payment
                      Row(
                        children: [
                          Text("Shop: ${order['shop']}"),
                          const Spacer(),
                          Chip(
                            label: Text(order['paymentType']),
                            backgroundColor: order['paymentType'] == "Cash"
                                ? Colors.green.shade100
                                : Colors.blue.shade100,
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Amount and View
                      Row(
                        children: [
                          const Icon(
                            Icons.attach_money,
                            color: Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Amount: Rs. ${order['amount']}",
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              _showOrderDetails(context, order);
                            },
                            child: const Text("View Details"),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Status Chip + Actions
                      Row(
                        children: [
                          Chip(
                            label: Text(order['status']),
                            backgroundColor: _statusColor(order['status']),
                            labelStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          if (order['status'] == 'Pending')
                            TextButton(
                              onPressed: () {
                                Provider.of<AppDataProvider>(
                                  context,
                                  listen: false,
                                ).forwardOrder(order['id']);
                              },
                              child: const Text("Forward"),
                            ),
                          if (order['status'] == 'Forwarded')
                            TextButton(
                              onPressed: () {
                                Provider.of<AppDataProvider>(
                                  context,
                                  listen: false,
                                ).markOrderReceived(order['id']);
                              },
                              child: const Text("Mark Received"),
                            ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              _showDeleteDialog(context, order['id']);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Forwarded':
        return Colors.blue;
      case 'Received':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _showDeleteDialog(BuildContext context, int id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Order?"),
        content: const Text("Are you sure you want to delete this order?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Provider.of<AppDataProvider>(
                context,
                listen: false,
              ).deleteOrder(id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(BuildContext context, Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Wrap(
          children: [
            ListTile(title: Text("🛒 Item: ${order['items']}")),
            ListTile(title: Text("📍 Shop: ${order['shop']}")),
            ListTile(title: Text("👤 Employee: ${order['employee']}")),
            ListTile(title: Text("💳 Payment: ${order['paymentType']}")),
            ListTile(title: Text("📝 Notes: ${order['notes']}")),
            ListTile(title: Text("📅 Date: ${order['date']}")),
            ListTile(title: Text("📦 Status: ${order['status']}")),
          ],
        ),
      ),
    );
  }
}
