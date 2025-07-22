import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';
import '../widgets/edit_sale_modal.dart';
import '../screens/login_screen.dart';

/// Shows a confirmation dialog before logging out.
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

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // rebuild each second to update countdown timers
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatCountdown(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final user = appData.loggedInUser ?? {};
    final role = (user['role'] ?? '').toString().toLowerCase();
    final employeeName = user['name'] as String? ?? '';

    // Fetch sales list per role
    final salesList = role == 'employee'
        ? appData.sales
        : role == 'manager'
            ? appData.allSales
            : appData.allSales;

    final title = role == 'employee'
        ? 'My Recent Sales'
        : role == 'manager'
            ? 'Sales Overview'
            : 'All Sales';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () => showPlatformLogoutDialog(context),
          ),
        ],
      ),
      body: salesList.isEmpty
          ? Center(
              child: Text(
                role == 'employee'
                    ? 'No recent sales to display.'
                    : 'No sales recorded yet.',
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: salesList.length,
              itemBuilder: (_, index) {
                final sale = salesList[index];
                final createdAt = sale['createdAt'] as DateTime;
                final elapsed = DateTime.now().difference(createdAt).inSeconds;
                final canEdit = elapsed < 300;
                final secondsLeft = 300 - elapsed;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('💲 Sale ID: ${sale['id']}'),
                        Text('🏪 Shop: ${sale['shop']}'),
                        Text('👤 Added by: ${sale['addedBy']}'),
                        Text('💰 Amount: Rs. ${sale['amount']}'),
                        Text('⏰ Time: ${createdAt.toLocal()}'),
                        if (role == 'employee' && sale['addedBy'] == employeeName)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              canEdit
                                  ? '⏱ Edit left: ${_formatCountdown(secondsLeft)}'
                                  : '❌ Edit time expired',
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
                            // Employee actions
                            if (role == 'employee' && sale['addedBy'] == employeeName)
                              if (canEdit)
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.edit),
                                  label: const Text('Edit'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                  onPressed: () => showDialog(
                                    context: context,
                                    builder: (_) => EditSaleModal(
                                      initialAmount: sale['amount'] as double,
                                      onSubmit: (updated) {
                                        appData.updateSaleAmount(sale['id'], updated);
                                        Navigator.of(context).pop();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Sale updated')),
                                        );
                                      },
                                    ),
                                  ),)
                              else
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.request_page),
                                  label: const Text('Request Edit'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                                  onPressed: () {
                                    appData.requestSaleEdit(sale['id'], employeeName);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Edit request sent')),
                                    );
                                  },
                                ),

                            // Admin delete
                            if (role == 'admin')
                              ElevatedButton.icon(
                                icon: const Icon(Icons.delete),
                                label: const Text('Delete'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                onPressed: () {
                                  appData.deleteSale(sale['id'].toString());
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Sale deleted')),
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
}
