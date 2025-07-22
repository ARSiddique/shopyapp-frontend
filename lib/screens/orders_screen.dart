import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';
import '../widgets/edit_order_model.dart';
import './login_screen.dart';

/// Confirm logout dialog (reuse across screens)
void showPlatformLogoutDialog(BuildContext context) {
  final appData = Provider.of<AppDataProvider>(context, listen: false);
  if (Platform.isIOS) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Logout?'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Logout'),
            onPressed: () {
              Navigator.of(context).pop();
              appData.logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
          ),
        ],
      ),
    );
  } else {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('Logout'),
            onPressed: () {
              Navigator.of(context).pop();
              appData.logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Confirm exit dialog (back button)
Future<bool> showPlatformExitDialog(BuildContext context) async {
  final result = await (Platform.isIOS
      ? showCupertinoDialog<bool>(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: const Text('Exit App?'),
            content: const Text('Do you want to quit the app?'),
            actions: [
              CupertinoDialogAction(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                child: const Text('Quit'),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        )
      : showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Exit App'),
            content: const Text('Do you want to quit the app?'),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              TextButton(
                child: const Text('Quit'),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ));
  return result ?? false;
}

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
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _confirmDelete(String orderId) async {
    final should = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Order?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (should == true) {
      if (!mounted) return;
      Provider.of<AppDataProvider>(context, listen: false).deleteOrder(orderId);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Order deleted')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final user = appData.loggedInUser ?? {};
    final role = (user['role'] ?? '').toString().toLowerCase();
    final name = user['name']?.toString() ?? '';

    // Fetch orders based on role: employee sees only their orders; manager and admin see all
    final myOrders = role == 'employee'
        ? appData.orders.where((o) => o['employee'] == name).toList()
        : appData.orders;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: Text(
          role == 'employee'
              ? 'My Orders'
              : role == 'manager'
              ? 'Assigned Orders'
              : 'All Orders', style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () => showPlatformLogoutDialog(context),
          ),
        ],
      ),
      body: myOrders.isEmpty
          ? const Center(child: Text('No orders available'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: myOrders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, index) {
                final order = myOrders[index];
                final created = order['createdAt'] as DateTime;
                final elapsed = DateTime.now().difference(created);
                final canEdit = elapsed.inMinutes < 10;
                final secondsLeft = 600 - elapsed.inSeconds;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('🧾 Order ID: ${order['id']}'),
                        Text('🏪 Shop: ${order['shop']}'),
                        Text('👤 Employee: ${order['employee']}'),
                        Text('💵 Amount: Rs. ${order['amount']}'),
                        const SizedBox(height: 8),
                        if (order['employee'] == name)
                          Text(
                            canEdit
                                ? '⏱ Edit Time Left: ${_format(countdown: secondsLeft)}'
                                : '❌ Edit time expired',
                            style: TextStyle(
                              color: canEdit ? Colors.orange : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            if (order['employee'] == name && canEdit)
                              ElevatedButton.icon(
                                icon: const Icon(Icons.edit),
                                label: const Text('Edit'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                ),
                                onPressed: () => showDialog(
                                  context: context,
                                  builder: (_) =>
                                      EditOrderModal(orderData: order),
                                ),
                              ),
                            if (order['employee'] == name && !canEdit)
                              ElevatedButton.icon(
                                icon: const Icon(Icons.request_page),
                                label: const Text('Request Edit'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueGrey,
                                ),
                                onPressed: () {
                                  appData.addEditRequest(
                                    type: 'order',
                                    itemId: order['id'],
                                    reason: 'Employee requested edit',
                                    requestedBy: name,
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Edit request sent'),
                                    ),
                                  );
                                },
                              ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.delete),
                              label: const Text('Delete'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: () =>
                                  _confirmDelete(order['id'].toString()),
                            ),
                            if ((role == 'manager' || role == 'admin') &&
                                order['status'] != 'Received')
                              ElevatedButton.icon(
                                icon: const Icon(Icons.check_circle),
                                label: const Text('Mark Received'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                                onPressed: () {
                                  appData.markOrderReceived(
                                    order['id'].toString(),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Order marked as received'),
                                    ),
                                  );
                                },
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

  String _format({required int countdown}) {
    final m = (countdown ~/ 60).toString().padLeft(2, '0');
    final s = (countdown % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
