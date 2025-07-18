import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';
import '../widgets/edit_sale_modal.dart';

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

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context, listen: false);
    ;
    final user = appData.loggedInUser ?? {};
    final role = (user['role'] ?? '').toString().toLowerCase();
    final employeeName = user['name'] as String? ?? '';
    final assignedShops = List<String>.from(user['assignedShops'] ?? []);

    // Determine which sales to show
    final List<Map<String, dynamic>> salesList = role == 'employee'
        // Only show employee's recent (last 5m) sales
        ? appData.sales
        : role == 'manager'
        // Manager: all sales in assigned shops
        ? appData.allSales
              .where((s) => assignedShops.contains(s['shop']))
              .toList()
        // Admin: all sales
        : appData.allSales;

    // If employee has no summary view, deny or show their list
    if (role == 'employee') {
      return Scaffold(
        appBar: AppBar(
          title: const Text("My Recent Sales"),
          backgroundColor: Colors.deepPurple,
        ),
        body: salesList.isEmpty
            ? const Center(child: Text("No recent sales to display."))
            : _buildList(salesList, role, employeeName),
      );
    }

    // Manager & Admin summary header
    return Scaffold(
      appBar: AppBar(
        title: Text(role == 'manager' ? "Sales for My Shops" : "All Sales"),
        backgroundColor: Colors.deepPurple,
      ),
      body: salesList.isEmpty
          ? const Center(child: Text("No sales recorded yet."))
          : Column(
              children: [
                // Optional summary bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    role == 'manager'
                        ? "Showing ${salesList.length} sales in your shops"
                        : "Total Sales: ${salesList.length}",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(child: _buildList(salesList, role, employeeName)),
              ],
            ),
    );
  }

  Widget _buildList(
    List<Map<String, dynamic>> salesList,
    String role,
    String employeeName,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: salesList.length,
      itemBuilder: (context, index) {
        final sale = salesList[index];
        final createdAt = sale['createdAt'] as DateTime;
        final elapsed = DateTime.now().difference(createdAt);
        final canEdit = elapsed.inMinutes < 5;
        final secondsLeft = 300 - elapsed.inSeconds;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("💲 Sale ID: ${sale['id']}"),
                Text("🏪 Shop: ${sale['shop']}"),
                Text("👤 Added by: ${sale['addedBy']}"),
                Text("💰 Amount: Rs. ${sale['amount']}"),
                Text("⏰ Time: ${createdAt.toLocal()}"),
                if (role == 'employee' && sale['addedBy'] == employeeName)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      canEdit
                          ? "⏱ Edit Time Left: ${_formatCountdown(secondsLeft)}"
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
                    // Employee: Edit or Request Edit
                    if (role == 'employee' && sale['addedBy'] == employeeName)
                      if (canEdit)
                        ElevatedButton.icon(
                          onPressed: () {
                            final provider = Provider.of<AppDataProvider>(
                              context,
                              listen: false,
                            );
                            showDialog(
                              context: context,
                              builder: (_) => EditSaleModal(
                                initialAmount: sale['amount'] as double,
                                onSubmit: (updatedAmount) {
                                  // Update through the provider, then close the dialog
                                  provider.updateSaleAmount(
                                    sale['id'],
                                    updatedAmount,
                                  );
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Sale updated'),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                          icon: const Icon(Icons.edit),
                          label: const Text("Edit"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: () {
                            final provider = Provider.of<AppDataProvider>(
                              context,
                              listen: false,
                            );
                            provider.requestSaleEdit(
                              sale['id'],
                              employeeName,
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

                    // Admin: Delete
                    if (role == 'admin')
                      ElevatedButton.icon(
                        onPressed: () {
                           final provider = Provider.of<AppDataProvider>(
                            context,
                            listen: false,
                          );
                          provider.deleteSale(sale['id'].toString());
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Sale deleted')),
                          );
                        },
                        icon: const Icon(Icons.delete),
                        label: const Text("Delete"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatCountdown(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }
}
