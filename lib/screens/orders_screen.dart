import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';
import '../widgets/edit_order_model.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Rebuild every second to update countdown timers
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final user = appData.loggedInUser ?? {};
    final role = user['role'] ?? '';
    final employeeName = user['name'] ?? '';
    final assignedShops = List<String>.from(user['assignedShops'] ?? []);

    // Role‑based filtering:
    final List<Map<String, dynamic>> myOrders = role == 'employee'
        ? appData.orders.where((o) => o['employee'] == employeeName).toList()
        : role == 'manager'
        ? appData.orders
              .where((o) => assignedShops.contains(o['shop']))
              .toList()
        : appData.orders;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          role == 'employee'
              ? 'My Orders'
              : role == 'manager'
              ? 'Assigned Orders'
              : 'All Orders',
        ),
        backgroundColor: Colors.deepPurple,
      ),
      body: myOrders.isEmpty
          ? const Center(child: Text("No orders available"))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: myOrders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final order = myOrders[index];
                final createdAt = order['createdAt'] as DateTime;
                final elapsed = DateTime.now().difference(createdAt);
                final canEdit = elapsed.inMinutes < 10;
                final secondsLeft = 600 - elapsed.inSeconds;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("🧾 Order ID: ${order['id']}"),
                        Text("🏪 Shop: ${order['shop']}"),
                        Text("👤 Employee: ${order['employee']}"),
                        Text("💵 Amount: Rs. ${order['amount']}"),
                        const SizedBox(height: 8),
                        if (order['employee'] == employeeName)
                          Text(
                            canEdit
                                ? "⏱ Edit Time Left: ${formatCountdown(secondsLeft)}"
                                : "❌ Edit time expired",
                            style: TextStyle(
                              color: canEdit ? Colors.orange : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            // Edit button (within 10m)
                            if (order['employee'] == employeeName && canEdit)
                              ElevatedButton.icon(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) =>
                                        EditOrderModal(orderData: order),
                                  );
                                },
                                icon: const Icon(Icons.edit),
                                label: const Text("Edit"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                ),
                              ),

                            // Request Edit (after 10m)
                            if (order['employee'] == employeeName && !canEdit)
                              ElevatedButton.icon(
                                onPressed: () {
                                  appData.addEditRequest(
                                    type: 'order',
                                    itemId: order['id'],
                                    reason: 'Employee requested edit',
                                    requestedBy: employeeName,
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Edit request sent'),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.request_page),
                                label: const Text("Request Edit"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueGrey,
                                ),
                              ),

                            // Delete (everyone can delete their own; admin deletes any)
                            ElevatedButton.icon(
                              onPressed: () {
                                appData.deleteOrder(order['id'].toString());
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Order deleted"),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.delete),
                              label: const Text("Delete"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                            ),

                            // Mark as Received (manager & admin)
                            if ((role == 'manager' || role == 'admin') &&
                                order['status'] != 'Received')
                              ElevatedButton.icon(
                                onPressed: () {
                                  appData.markOrderReceived(
                                    order['id'].toString(),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Order marked as received"),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.check_circle),
                                label: const Text("Mark Received"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

String formatCountdown(int totalSeconds) {
  final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return "$minutes:$seconds";
}
