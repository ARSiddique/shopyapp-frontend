import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/app_data_provider.dart';
import '../widgets/summary_card.dart';
import '../widgets/search_and_filter_bar.dart';
import '../widgets/edit_sale_modal.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  String _searchQuery = '';
  String _statusFilter = 'All';

  void _showRequestEditDialog(BuildContext context, Map<String, dynamic> sale) {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Request Sale Edit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'New Amount'),
            ),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(labelText: 'Reason'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newAmount =
                  double.tryParse(amountController.text.trim()) ?? 0.0;
              final reason = reasonController.text.trim();

              if (newAmount > 0 && reason.isNotEmpty) {
                Provider.of<AppDataProvider>(
                  context,
                  listen: false,
                ).requestSaleEdit(sale['id'], reason, newAmount);

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Edit request sent')),
                );
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String saleId) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Sale?'),
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

    if (!mounted || shouldDelete != true) return;

    await FirebaseFirestore.instance.collection('sales').doc(saleId).delete();
    if (!mounted) return;
    Provider.of<AppDataProvider>(context, listen: false).deleteSale(saleId);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Sale deleted')));
  }

  void _openEditSaleModal(BuildContext context, Map<String, dynamic> sale) {
    showDialog(
      context: context,
      builder: (_) => EditSaleModal(
        initialAmount: (sale['total'] ?? 0).toDouble(),
        onSubmit: (newAmount) async {
          final appData = Provider.of<AppDataProvider>(context, listen: false);
          final updated = Map<String, dynamic>.from(sale);
          updated['total'] = newAmount;

          try {
            await FirebaseFirestore.instance
                .collection('sales')
                .doc(sale['id'].toString())
                .update({'total': newAmount});

            appData.editSale(updated);
            if (context.mounted) Navigator.pop(context);

            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Sale updated')));
          } catch (e) {
            debugPrint('Error updating sale: $e');
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Update failed')));
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final user = appData.loggedInUser ?? {};
    final role = (user['role'] ?? '').toString().toLowerCase();
    final name = user['name']?.toString() ?? '';

    List<Map<String, dynamic>> mySales = role == 'employee'
        ? appData.sales.where((s) => s['employee'] == name).toList()
        : appData.sales;

    // Search & Filter
    mySales = mySales.where((s) {
      final matchesSearch = s['employee'].toString().toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      final matchesFilter =
          _statusFilter == 'All' ||
          (_statusFilter == 'Cash' && (s['cash'] ?? 0) > 0) ||
          (_statusFilter == 'Card' && (s['card'] ?? 0) > 0) ||
          (_statusFilter == 'Other' && (s['other'] ?? 0) > 0);
      return matchesSearch && matchesFilter;
    }).toList();

    // Summary values
    final totalCount = mySales.length;
    final totalCash = mySales.fold<num>(
      0,
      (sum, s) => sum + (s['cash'] is num ? s['cash'] : 0),
    );
    final totalCard = mySales.fold<num>(
      0,
      (sum, s) => sum + (s['card'] is num ? s['card'] : 0),
    );
    final totalOther = mySales.fold<num>(
      0,
      (sum, s) => sum + (s['other'] is num ? s['other'] : 0),
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: Text(
          role == 'employee' ? 'My Sales' : 'All Sales',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              childAspectRatio: 1.4,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                SummaryCard(
                  icon: Icons.attach_money,
                  title: 'Total',
                  count: totalCount.toString(),
                  color: Colors.deepPurple,
                ),
                SummaryCard(
                  icon: Icons.money,
                  title: 'Cash',
                  count: totalCash.toStringAsFixed(0),
                  color: Colors.green,
                ),
                SummaryCard(
                  icon: Icons.credit_card,
                  title: 'Card',
                  count: totalCard.toStringAsFixed(0),
                  color: Colors.blue,
                ),
                SummaryCard(
                  icon: Icons.account_balance_wallet,
                  title: 'Other',
                  count: totalOther.toStringAsFixed(0),
                  color: Colors.orange,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SearchAndFilterBar(
              onSearchChanged: (query) => setState(() => _searchQuery = query),
              filterOptions: const ['All', 'Cash', 'Card', 'Other'],
              selectedFilter: _statusFilter,
              onFilterChanged: (value) => setState(() => _statusFilter = value),
            ),
          ),
          const Divider(),
          Expanded(
            child: mySales.isEmpty
                ? const Center(child: Text('No sales yet'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: mySales.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, index) {
                      final sale = mySales[index];
                     final dynamic createdAt = sale['createdAt'];
                      DateTime? displayTime;

                      if (createdAt is Timestamp) {
                        displayTime = createdAt.toDate();
                      } else if (createdAt is DateTime) {
                        displayTime = createdAt;
                      } else if (createdAt is String) {
                        displayTime = DateTime.tryParse(createdAt);
                      } else {
                        displayTime = null;
                      }
                      final formatted = displayTime != null
                          ? DateFormat('dd MMM, hh:mm a').format(displayTime)
                          : 'N/A';

                      return Card(
                        child: ListTile(
                          title: Text('💵 Rs. ${sale['total']}'),
                          subtitle: Text(
                            '🧍 ${sale['employee']} - 🕒 $formatted',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.orange,
                                ),
                                onPressed: () =>
                                    _openEditSaleModal(context, sale),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () =>
                                    _confirmDelete(sale['id'].toString()),
                              ),
                              if (role == 'employee')
                                IconButton(
                                  icon: const Icon(
                                    Icons.request_page,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () =>
                                      _showRequestEditDialog(context, sale),
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
