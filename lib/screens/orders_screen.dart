// lib/screens/orders_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

import '../providers/app_data_provider.dart';
import 'add_order_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, this.initialStatusFilter = 'All'});
  final String initialStatusFilter; // All | Pending | Forwarded | Received

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  bool _busy = false;
  late String _statusFilter = widget.initialStatusFilter;
  final _dateFmt = DateFormat('dd MMM, hh:mm a');

  Future<void> _safeRun(Future<void> Function() fn) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await fn();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh(AppDataProvider app) => app.fetchOrders();

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> data) {
    if (_statusFilter == 'All') return data;
    return data
        .where((o) => (o['status'] ?? 'Pending').toString() == _statusFilter)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppDataProvider>().fetchOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();
    final me = app.loggedInUser ?? {};
    final role = (me['role'] ?? 'employee').toString().toLowerCase();
    final isEmployee = role == 'employee';

    final allOrders = app.orders;
    final orders = _applyFilter(allOrders);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          PopupMenuButton<String>(
            initialValue: _statusFilter,
            onSelected: (v) => setState(() => _statusFilter = v),
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'All', child: Text('All')),
              PopupMenuItem(value: 'Pending', child: Text('Pending')),
              PopupMenuItem(value: 'Forwarded', child: Text('Forwarded')),
              PopupMenuItem(value: 'Received', child: Text('Received')),
            ],
            icon: const Icon(Icons.filter_list),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(app),
        child: _busy
            ? const Center(child: CircularProgressIndicator())
            : orders.isEmpty
                ? ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 120),
                    children: [
                      const Center(child: Text('No orders found')),
                      const SizedBox(height: 12),
                      Center(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Add Order'),
                          onPressed: _busy
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const AddOrderScreen(),
                                    ),
                                  );
                                },
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final o = orders[i];

                      final id = (o['id'] ?? '').toString();
                      final status = (o['status'] ?? 'Pending').toString();
                      final isForwarded = status == 'Forwarded';
                      final isReceived = status == 'Received';

                      // schema fallbacks (old vs new keys)
                      final wholesalerLabel =
                          (o['wholesalerName'] ?? o['wholesaler'] ?? 'Wholesaler')
                              .toString();
                      final shopLabel =
                          (o['shopName'] ?? o['shop'] ?? '-').toString();

                      final amount = (o['amount'] is num)
                          ? (o['amount'] as num).toDouble()
                          : double.tryParse('${o['amount'] ?? 0}') ?? 0.0;

                      final createdAtRaw = o['createdAt'];
                      final createdAt = createdAtRaw is DateTime
                          ? createdAtRaw
                          : (createdAtRaw is Timestamp
                              ? createdAtRaw.toDate()
                              : null);

                      final createdBy = (o['createdByName'] ?? '').toString();
                      final note = (o['note'] ?? '').toString();
                      final invoiceUrl = (o['invoiceUrl'] ?? '').toString();

                      return Card(
                        elevation: 1.5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top row: Wholesaler + Amount
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      wholesalerLabel,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'Amount: ${amount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),

                              // Shop + CreatedAt
                              Row(
                                children: [
                                  Icon(Icons.storefront,
                                      size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Shop: $shopLabel',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (createdAt != null) ...[
                                    const SizedBox(width: 8),
                                    Icon(Icons.access_time,
                                        size: 16, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text(_dateFmt.format(createdAt)),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),

                              if (createdBy.isNotEmpty)
                                Text(
                                  'By: $createdBy',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                  ),
                                ),

                              if (note.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Note: $note',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),

                              if (invoiceUrl.isNotEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Invoice attached',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),

                              const SizedBox(height: 8),

                              // Status + Actions
                              Row(
                                children: [
                                  _StatusChip(status: status),
                                  const Spacer(),
                                  // Forward (allowed unless already forwarded/received)
                                  ElevatedButton(
                                    onPressed: (_busy || isForwarded || isReceived)
                                        ? null
                                        : () => _safeRun(() async {
                                              await context
                                                  .read<AppDataProvider>()
                                                  .forwardOrder(id);
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text('Order forwarded.'),
                                                ),
                                              );
                                            }),
                                    child: const Text('Forward'),
                                  ),
                                  const SizedBox(width: 8),
                                  // Received (disabled for employees)
                                  ElevatedButton(
                                    onPressed: (_busy || isReceived || isEmployee)
                                        ? null
                                        : () => _safeRun(() async {
                                              await context
                                                  .read<AppDataProvider>()
                                                  .markOrderReceived(id);
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text('Order received.'),
                                                ),
                                              );
                                            }),
                                    child: const Text('Received'),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _busy
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddOrderScreen()),
                );
              },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case 'Forwarded':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
        break;
      case 'Received':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        break;
      default:
        bg = Colors.blueGrey.shade50;
        fg = Colors.blueGrey.shade800;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.2)), // 👈 FIXED
      ),
      child: Text(
        status,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
