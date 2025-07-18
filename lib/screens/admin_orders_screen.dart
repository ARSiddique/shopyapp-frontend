import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';
import 'edit_order_modal.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  Timer? _timer;

   @override
  void initState() {
    super.initState();
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
    final user = appData.loggedInUser;
    final role = user?['role'] ?? '';
    final orders = appData.orders;
    // final employeeName = user?['name'];

  
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Orders"),
        backgroundColor: Colors.deepPurple,
      ),
      body: orders.isEmpty
          ? const Center(child: Text("No orders available"))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                final createdAt = order['createdAt'] as DateTime;
                final elapsed = DateTime.now().difference(createdAt);
                final canEdit = elapsed.inMinutes < 10;
                final secondsLeft = 600 - elapsed.inSeconds;
                final employeeName = user?['name'];

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
                        Text("💵 Amount: ${order['amount']}"),
                        Text("📅 Time: ${createdAt.toLocal()}"),
                        if (order['employee'] == employeeName)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              canEdit
                                  ? "⏳ Edit Time Left: ${formatCountdown(secondsLeft)}"
                                  : "❌ Edit time expired",
                              style: TextStyle(
                                color: canEdit ? Colors.orange : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
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
                            if (order['employee'] == employeeName && !canEdit)
                              ElevatedButton.icon(
                                onPressed: () {
                                  appData.addEditRequest(
                                    type: 'order',
                                    itemId: order['id'],
                                    reason: 'Edit request (auto)',
                                    requestedBy: employeeName ?? '',
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Edit request sent to manager",
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.request_page),
                                label: const Text("Request Edit"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueGrey,
                                ),
                              ),
                            if (role == 'admin')
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
                            if ((role == 'admin' || role == 'manager') &&
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
                                icon: const Icon(Icons.check),
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
  String formatCountdown(int totalSeconds) {
    if (totalSeconds <= 0) return "00:00";
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }


  void _showEditRequestDialog(BuildContext context, int orderId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Request Edit"),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: "Reason for edit"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isNotEmpty) {
                Provider.of<AppDataProvider>(
                  context,
                  listen: false,
                ).requestOrderEdit(orderId, reason);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Edit request sent to manager")),
                );
              }
            },
            child: const Text("Submit"),
          ),
        ],
      ),
    );
  }
}
