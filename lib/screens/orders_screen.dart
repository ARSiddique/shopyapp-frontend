import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';
import '../widgets/edit_order_modal.dart';
import '../widgets/summary_card.dart';
import '../widgets/search_and_filter_bar.dart';


class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();

}

class _OrdersScreenState extends State<OrdersScreen> {
  Timer? _timer;
   String _searchQuery = '';
  String _statusFilter = 'All';

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

  // void _showLogoutDialog() {
  //   final appData = Provider.of<AppDataProvider>(context, listen: false);
  //   if (Platform.isIOS) {
  //     showCupertinoDialog(
  //       context: context,
  //       builder: (_) => CupertinoAlertDialog(
  //         title: const Text('Logout?'),
  //         content: const Text('Are you sure you want to logout?'),
  //         actions: [
  //           CupertinoDialogAction(
  //             child: const Text('Cancel'),
  //             onPressed: () => Navigator.of(context).pop(),
  //           ),
  //           CupertinoDialogAction(
  //             isDestructiveAction: true,
  //             child: const Text('Logout'),
  //             onPressed: () {
  //               Navigator.of(context).pop();
  //               appData.logout();
  //             },
  //           ),
  //         ],
  //       ),
  //     );
  //   } else {
  //     showDialog(
  //       context: context,
  //       builder: (_) => AlertDialog(
  //         title: const Text('Logout'),
  //         content: const Text('Are you sure you want to logout?'),
  //         actions: [
  //           TextButton(
  //             child: const Text('Cancel'),
  //             onPressed: () => Navigator.of(context).pop(),
  //           ),
  //           TextButton(
  //             child: const Text('Logout'),
  //             onPressed: () {
  //               Navigator.of(context).pop();
  //               appData.logout();
  //             },
  //           ),
  //         ],
  //       ),
  //     );
  //   }
  // }

  String _formatCountdown(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final user = appData.loggedInUser ?? {};
    final role = (user['role'] ?? '').toString().toLowerCase();
    final name = user['name']?.toString() ?? '';

    List<Map<String, dynamic>> myOrders = role == 'employee'
    ? appData.orders.where((o) => o['employee'] == name).toList()
    : appData.orders;

myOrders = myOrders.where((o) {
  final matchesSearch = o['items']
      .toString()
      .toLowerCase()
      .contains(_searchQuery.toLowerCase());
  final matchesFilter =
      _statusFilter == 'All' || o['status'] == _statusFilter;
  return matchesSearch && matchesFilter;
}).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: Text(
          role == 'employee'
              ? 'My Orders'
              : role == 'manager'
              ? 'Assigned Orders'
              : 'All Orders',
          style: const TextStyle(color: Colors.white),
        ),
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.logout, color: Colors.red),
        //     onPressed: _showLogoutDialog,
        //   ),
        // ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SummaryCard(
                  title: 'Total',
                  count: appData.orders.length.toString(),
                  color: Colors.deepPurple,
                  icon: Icons.receipt_long,
                ),
                SummaryCard(
                  title: 'Pending',
                  count: appData.orders
                      .where((o) => o['status'] == 'Pending')
                      .length
                      .toString(),
                  color: Colors.orange,
                  icon: Icons.hourglass_empty,
                ),
                SummaryCard(
                  title: 'Forwarded',
                  count: appData.orders
                      .where((o) => o['status'] == 'Forwarded')
                      .length
                      .toString(),
                  color: Colors.blue,
                  icon: Icons.send,
                ),
                SummaryCard(
                  title: 'Received',
                  count: appData.orders
                      .where((o) => o['status'] == 'Received')
                      .length
                      .toString(),
                  color: Colors.green,
                  icon: Icons.check_circle,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SearchAndFilterBar(
              onSearchChanged: (query) => setState(() => _searchQuery = query),
              filterOptions: const ['All', 'Pending', 'Forwarded', 'Received'],
              selectedFilter: _statusFilter,
              onFilterChanged: (value) => setState(() => _statusFilter = value),
            ),
          ),
          const Divider(),
          Expanded(
            child: myOrders.isEmpty
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
                                      ? '⏱ Edit Time Left: ${_formatCountdown(secondsLeft)}'
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
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
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
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Order marked as received',
                                            ),
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
          ),
        ],
      ),
    );
  }
  
}
