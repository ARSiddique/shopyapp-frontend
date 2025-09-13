// lib/screens/orders_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

import '../providers/app_data_provider.dart';
import 'add_order_screen.dart';
import 'wholesalers_list_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({
    super.key,
    this.initialStatusFilter = 'All',
    this.focusWholesaler,
  });
  final String initialStatusFilter; // All | Pending | Forwarded | Received
  final String? focusWholesaler;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  bool _busy = false;
  late String _statusFilter = widget.initialStatusFilter;
  String? _wholesalerFilter;
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
    var out = data;
    if (_statusFilter != 'All') {
      out = out
          .where((o) => (o['status'] ?? 'Pending').toString() == _statusFilter)
          .toList();
    }
    if ((_wholesalerFilter ?? '').isNotEmpty) {
      out = out.where((o) {
        final w = (o['wholesalerName'] ?? o['wholesaler'] ?? '').toString();
        return w.toLowerCase() == _wholesalerFilter!.toLowerCase();
      }).toList();
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    _wholesalerFilter = widget.focusWholesaler;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final app = context.read<AppDataProvider>();
      final role = (app.loggedInUser?['role'] ?? '')
          .toString()
          .toLowerCase()
          .trim();

      // Admin/Manager → force shop selection if empty
      if ((role == 'admin' || role == 'manager') &&
          (app.selectedShopName == null || app.selectedShopName!.isEmpty)) {
        await _ensureShopSelected(context);
      }

      await app.fetchOrders();
    });
  }

  // ---- inline shop picker (bottom sheet) ----
  Future<void> _ensureShopSelected(BuildContext context) async {
    final app = context.read<AppDataProvider>();
    if ((app.selectedShopName ?? '').isNotEmpty) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Consumer<AppDataProvider>(
          builder: (_, app2, __) {
            final shops = app2.shops
                .where((s) => (s['isDeleted'] ?? false) != true)
                .toList();
            if (shops.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No shops to select.'),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: shops.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final s = shops[i];
                final id = (s['id'] ?? '').toString();
                final name = (s['name'] ?? 'Unnamed').toString();
                return ListTile(
                  leading: const Icon(Icons.store),
                  title: Text(name),
                  onTap: () {
                    Navigator.pop(context);
                    app.setSelectedShop(id, name);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  // wholesaler → AddOrder
  Future<void> _startAddOrder(BuildContext context) async {
    final app = context.read<AppDataProvider>();

    if ((app.selectedShopName ?? '').isEmpty) {
      await _ensureShopSelected(context);
    }
    final shopName = app.selectedShopName ?? '';
    if (shopName.isEmpty) return;

    final selected = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const WholesalersListScreen(selectMode: true),
      ),
    );
    if (selected == null || selected.trim().isEmpty) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddOrderScreen(
          shopName: shopName,
          wholesalerName: selected.trim(),
        ),
      ),
    );
  }

  Future<void> _showAddWhDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    final app = context.read<AppDataProvider>();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Wholesaler'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
            TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: 'Address')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final err = await app.addOrUpdateWholesaler(
                name: nameCtrl.text,
                phone: phoneCtrl.text,
                address: addrCtrl.text,
              );
              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(err == null ? 'Wholesaler added' : 'Failed: $err')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();
    final me = app.loggedInUser ?? {};
    final role = (me['role'] ?? 'employee').toString().toLowerCase();
    final isManagerOrAdmin = role == 'manager' || role == 'admin';
    final myShop = app.selectedShopName ?? '';

    final allOrders = app.orders;
    final orders = _applyFilter(allOrders);

    final Map<String, int> pendingCounts = {};
    for (final o in allOrders) {
      final st = (o['status'] ?? 'Pending').toString();
      if (st == 'Pending' || st == 'Placed' || st == 'Forwarded') {
        final w = (o['wholesalerName'] ?? o['wholesaler'] ?? 'Wholesaler').toString();
        if (w.isEmpty) continue;
        pendingCounts[w] = (pendingCounts[w] ?? 0) + 1;
      }
    }

    final canManage = isManagerOrAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          if (canManage)
            IconButton(
              tooltip: 'Add Wholesaler',
              icon: const Icon(Icons.person_add_alt_1),
              onPressed: _showAddWhDialog,
            ),
          IconButton(
            tooltip: 'Return Items',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Return Items screen TODO')),
              );
            },
            icon: const Icon(Icons.assignment_return_rounded),
          ),
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
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (pendingCounts.isNotEmpty) ...[
                    Text('Pending Orders from Wholesalers',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 1,
                      child: Column(
                        children: pendingCounts.entries.map((e) {
                          return ListTile(
                            title: Text(e.key),
                            trailing: Text('x${e.value}',
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            onTap: () {
                              setState(() {
                                _statusFilter = 'Pending';
                                _wholesalerFilter = e.key;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (orders.isEmpty) ...[
                    const SizedBox(height: 80),
                    const Center(child: Text('No orders found')),
                    const SizedBox(height: 12),
                    Center(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Order'),
                        onPressed: _busy ? null : () => _startAddOrder(context),
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        if ((_wholesalerFilter ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: InputChip(
                              label: Text('Wholesaler: $_wholesalerFilter'),
                              onDeleted: () => setState(() => _wholesalerFilter = null),
                            ),
                          ),
                        const Spacer(),
                        Text('Showing ${orders.length}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...orders.map(
                      (o) => _OrderCard(
                        data: o,
                        isManagerOrAdmin: isManagerOrAdmin,
                        myShopName: myShop,
                        dateFmt: _dateFmt,
                        onForward: (id) => _safeRun(() async {
                          await context.read<AppDataProvider>().forwardOrder(id);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Order forwarded.')),
                          );
                        }),
                        onReceived: (id) => _safeRun(() async {
                          await context.read<AppDataProvider>().markOrderReceived(id);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Order received.')),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _busy ? null : () => _startAddOrder(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.data,
    required this.isManagerOrAdmin,
    required this.myShopName,
    required this.dateFmt,
    required this.onForward,
    required this.onReceived,
  });

  final Map<String, dynamic> data;
  final bool isManagerOrAdmin;
  final String myShopName;
  final DateFormat dateFmt;
  final Future<void> Function(String id) onForward;
  final Future<void> Function(String id) onReceived;

  @override
  Widget build(BuildContext context) {
    final id = (data['id'] ?? '').toString();
    final status = (data['status'] ?? 'Pending').toString();
    final isForwarded = status == 'Forwarded';
    final isReceived = status == 'Received';

    final wholesalerLabel =
        (data['wholesalerName'] ?? data['wholesaler'] ?? 'Wholesaler').toString();
    final shopLabel = (data['shopName'] ?? data['shop'] ?? '-').toString();

    final amount = (data['amount'] is num)
        ? (data['amount'] as num).toDouble()
        : double.tryParse('${data['amount'] ?? 0}') ?? 0.0;

    final createdAtRaw = data['createdAt'];
    final createdAt = createdAtRaw is DateTime
        ? createdAtRaw
        : (createdAtRaw is Timestamp ? createdAtRaw.toDate() : null);

    final createdBy = (data['createdByName'] ?? '').toString();
    final note = (data['note'] ?? '').toString();
    final invoiceUrl = (data['invoiceUrl'] ?? '').toString();

    final belongsToMyShop = shopLabel == myShopName;

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(
                wholesalerLabel,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              'Amount: ${amount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.storefront, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Expanded(child: Text('Shop: $shopLabel', overflow: TextOverflow.ellipsis)),
            if (createdAt != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(dateFmt.format(createdAt)),
            ],
          ]),
          const SizedBox(height: 6),
          if (createdBy.isNotEmpty)
            Text('By: $createdBy', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          if (note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Note: $note', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
            ),
          if (invoiceUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.image, size: 16),
                  const SizedBox(width: 6),
                  const Text('Invoice attached', style: TextStyle(fontSize: 12)),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          child: InteractiveViewer(
                            child: Image.network(invoiceUrl, fit: BoxFit.contain),
                          ),
                        ),
                      );
                    },
                    child: const Text('See photo'),
                  )
                ],
              ),
            ),
          const SizedBox(height: 8),
          Row(children: [
            _StatusChip(status: status),
            const Spacer(),
            ElevatedButton(
              onPressed: (isForwarded || isReceived || !isManagerOrAdmin) ? null : () => onForward(id),
              child: const Text('Forward'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: (isReceived || !belongsToMyShop) ? null : () => onReceived(id),
              child: const Text('Received'),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    switch (status) {
      case 'Forwarded':
        bg = Colors.orange.shade50; fg = Colors.orange.shade800; break;
      case 'Received':
        bg = Colors.green.shade50;  fg = Colors.green.shade800;  break;
      default:
        bg = Colors.blueGrey.shade50; fg = Colors.blueGrey.shade800;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.2)),
      ),
      child: Text(
        status,
        style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
