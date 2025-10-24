import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../providers/app_data_provider.dart';
import 'add_order_screen.dart';          // Receive form (your current file)
import 'place_order_screen.dart';        // NEW: simple “place order” form

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({
    super.key,
    this.initialStatusFilter = 'All',
    this.focusWholesaler,
  });

  /// UI filter: All | Ordered | Forwarded | Received
  final String initialStatusFilter;
  final String? focusWholesaler;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

enum _OrdersView { list, table }

class _OrdersScreenState extends State<OrdersScreen> {
  bool _busy = false;
  late String _statusFilter;
  String? _wholesalerFilter;
  final _dateFmt = DateFormat('dd MMM, hh:mm a');
  bool _didPromptShop = false;

  _OrdersView _view = _OrdersView.table; // default table

  // ---------- helpers ----------
  String _uiStatusOf(dynamic raw) {
    final s = (raw ?? 'Pending').toString();
    if (s == 'Received') return 'Received';
    if (s == 'Forwarded') return 'Forwarded';
    // treat Pending/Placed/Created/etc as Ordered
    return 'Ordered';
  }

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
    var out =
        data.map((m) => {...m, 'uiStatus': _uiStatusOf(m['status'])}).toList();
    if (_statusFilter != 'All') {
      out = out
          .where((o) => (o['uiStatus'] as String) == _statusFilter)
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

    // ✅ Only map Pending/Placed → Ordered. Keep 'All' as is.
    if (widget.initialStatusFilter == 'Pending' ||
        widget.initialStatusFilter == 'Placed') {
      _statusFilter = 'Ordered';
    } else {
      _statusFilter = widget.initialStatusFilter;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPromptShop) return;
    _didPromptShop = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _promptShopEachVisit();
      if (!mounted) return;
      await context.read<AppDataProvider>().fetchOrders();
    });
  }

  // ---------- prompt/select shop (admin/manager only) ----------
  Future<void> _promptShopEachVisit() async {
    final app = context.read<AppDataProvider>();
    final role = (app.loggedInUser?['role'] ?? '').toString().toLowerCase();
    if (role != 'admin' && role != 'manager') return;

    final shopsAll =
        app.shops.where((s) => (s['isDeleted'] ?? false) != true).toList();

    if (shopsAll.isEmpty) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('No Shops'),
          content: const Text('Please add a shop first.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK')),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
      return;
    }

    final current = app.selectedShopName;

    final chosen = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: shopsAll.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final s = shopsAll[i];
            final id = (s['id'] ?? s['docId'] ?? '').toString();
            final name = (s['name'] ?? 'Unnamed').toString();
            final selected = name == current;
            return ListTile(
              leading: const Icon(Icons.store, color: Colors.white70),
              title:
                  Text(name, style: const TextStyle(color: Colors.white)),
              trailing:
                  selected ? const Icon(Icons.check, color: Colors.white) : null,
              onTap: () => Navigator.pop(context, {'id': id, 'name': name}),
            );
          },
        ),
      ),
    );

    if (!mounted) return;
    if (chosen == null) {
      Navigator.pop(context);
      return;
    }
    app.setSelectedShop(chosen['id']!, chosen['name']!);
  }

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
                child: Text('No shops to select.',
                    style: TextStyle(color: Colors.white)),
              );
            }
            return ListView.separated(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: shops.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final s = shops[i];
                final id = (s['id'] ?? '').toString();
                final name = (s['name'] ?? 'Unnamed').toString();
                return ListTile(
                  leading: const Icon(Icons.store, color: Colors.white70),
                  title:
                      Text(name, style: const TextStyle(color: Colors.white)),
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

  // FAB → Place Order (new screen)
  Future<void> _startAddOrder(BuildContext context) async {
    final app = context.read<AppDataProvider>();

    if ((app.selectedShopName ?? '').isEmpty) {
      await _ensureShopSelected(context);
      if (!mounted) return;
    }
    final shopName = app.selectedShopName ?? '';
    if (shopName.isEmpty) return;

    if (app.wholesalers.isEmpty) {
      await app.fetchWholesalers();
      if (!mounted) return;
    }

    final chosen = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        final list = app.wholesalers;
        if (list.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No wholesalers found. Use + to add one.',
                style: TextStyle(color: Colors.white)),
          );
        }
        return SafeArea(
          child: ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final name = (list[i]['name'] ?? '').toString();
              return ListTile(
                leading:
                    const Icon(Icons.local_shipping, color: Colors.white70),
                title:
                    Text(name, style: const TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context, name),
              );
            },
          ),
        );
      },
    );
    if (!mounted || chosen == null || chosen.trim().isEmpty) return;

    // (Optional) Keep your unique-per-day guard here if you still want it:
    // final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    // final already = app.orders.any((o) =>
    //     (o['shopName'] ?? o['shop']) == shopName &&
    //     (o['dayKey'] ?? '') == todayKey);
    // if (already) { ...return; }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaceOrderScreen(
          shopName: shopName,
          wholesalerName: chosen.trim(),
          // (optionally pass employeeName here)
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
        backgroundColor: const Color(0xFF1A2433),
        title:
            const Text('Add Wholesaler', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
                style: const TextStyle(color: Colors.white)),
            TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone'),
                style: const TextStyle(color: Colors.white)),
            TextField(
                controller: addrCtrl,
                decoration: const InputDecoration(labelText: 'Address'),
                style: const TextStyle(color: Colors.white)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
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
                SnackBar(
                    content: Text(err == null
                        ? 'Wholesaler added'
                        : 'Failed: $err')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();
    final me = app.loggedInUser ?? {};
    final role = (me['role'] ?? 'employee').toString().toLowerCase();
    final isManagerOrAdmin = role == 'manager' || role == 'admin';
    final myShop = app.selectedShopName ?? '';

    final allOrders = app.orders;

    // mapped for pending counts (unfiltered)
    final mappedAll = allOrders
        .map((m) => {...m, 'uiStatus': _uiStatusOf(m['status'])})
        .toList();

    // filtered list for cards
    var orders = _applyFilter(allOrders);

    // EMPLOYEE: show only last two own orders (any status)
    if (!isManagerOrAdmin) {
      final myUid = (app.loggedInUser?['uid'] ?? '').toString();
      orders = orders
          .where((o) => (o['createdByUid'] ?? '') == myUid)
          .toList()
        ..sort((a, b) {
          final ad = a['createdAt'] is DateTime
              ? a['createdAt'] as DateTime
              : ((a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000));
          final bd = b['createdAt'] is DateTime
              ? b['createdAt'] as DateTime
              : ((b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000));
          return bd.compareTo(ad);
        });
      if (orders.length > 2) {
        orders = orders.sublist(0, 2);
      }
    }

    // pending counts (Ordered + Forwarded)
    final Map<String, int> pendingCounts = {};
    for (final o in mappedAll) {
      final st = o['uiStatus'] as String;
      if (st == 'Ordered' || st == 'Forwarded') {
        final w =
            (o['wholesalerName'] ?? o['wholesaler'] ?? 'Wholesaler')
                .toString();
        if (w.isEmpty) continue;
        pendingCounts[w] = (pendingCounts[w] ?? 0) + 1;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          IconButton(
            tooltip:
                _view == _OrdersView.table ? 'List View' : 'Table View',
            icon: Icon(_view == _OrdersView.table
                ? Icons.view_list
                : Icons.grid_on),
            onPressed: () => setState(() {
              _view = _view == _OrdersView.table
                  ? _OrdersView.list
                  : _OrdersView.table;
            }),
          ),
          if (isManagerOrAdmin)
            IconButton(
              tooltip: 'Add Wholesaler',
              icon: const Icon(Icons.person_add_alt_1),
              onPressed: _showAddWhDialog,
            ),
          PopupMenuButton<String>(
            initialValue: _statusFilter,
            onSelected: (v) => setState(() => _statusFilter = v),
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'All', child: Text('All')),
              PopupMenuItem(value: 'Ordered', child: Text('Ordered')),
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
            : (_view == _OrdersView.table
                ? _TableView(
                    statusFilter: _statusFilter,
                    wholesalerFilter: _wholesalerFilter,
                    onOpenActions: (row) => _openOrderActionsSheet(
                      context: context,
                      row: row,
                      isManagerOrAdmin: isManagerOrAdmin,
                      myShop: myShop,
                    ),
                  )
                : _ListViewSection(
                    pendingCounts: pendingCounts,
                    orders: orders,
                    isManagerOrAdmin: isManagerOrAdmin,
                    myShop: myShop,
                    dateFmt: _dateFmt,
                    onStartAdd: () => _startAddOrder(context),
                    onForward: (id) => _safeRun(() async {
                      await context
                          .read<AppDataProvider>()
                          .forwardOrder(id);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Order forwarded.')),
                      );
                    }),
                    onReceived: (id) async {
                      // 👉 open Receive form instead of instant mark
                      final app = context.read<AppDataProvider>();
                      final order = app.orders.firstWhere((o) => o['id'] == id);
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddOrderScreen(
                            orderId: id,
                            shopName:
                                (order['shopName'] ?? order['shop'] ?? '').toString(),
                            wholesalerName: (order['wholesalerName'] ??
                                    order['wholesaler'] ??
                                    '')
                                .toString(),
                          ),
                        ),
                      );
                    },
                    onDelete: (id) => _safeRun(() async {
                      await context
                          .read<AppDataProvider>()
                          .deleteOrder(id);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Order deleted.')),
                      );
                    }),
                  )),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _busy ? null : () => _startAddOrder(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _openOrderActionsSheet({
    required BuildContext context,
    required Map<String, dynamic> row,
    required bool isManagerOrAdmin,
    required String myShop,
  }) async {
    final id = (row['id'] ?? '').toString();
    final uiStatus = _uiStatusOf(row['status']);
    final shop = (row['shopName'] ?? row['shop'] ?? '').toString();
    final belongsToMyShop = shop == myShop;

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.send),
              title: const Text('Forward'),
              enabled: isManagerOrAdmin && uiStatus == 'Ordered',
              onTap: !isManagerOrAdmin || uiStatus != 'Ordered'
                  ? null
                  : () async {
                      Navigator.pop(context);
                      await _safeRun(() => context
                          .read<AppDataProvider>()
                          .forwardOrder(id));
                    },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle),
              title: const Text('Mark Received'),
              enabled: belongsToMyShop && uiStatus != 'Received',
              onTap: !belongsToMyShop || uiStatus == 'Received'
                  ? null
                  : () async {
                      Navigator.pop(context);
                      // 👉 open Receive form
                      final app = context.read<AppDataProvider>();
                      final order =
                          app.orders.firstWhere((o) => o['id'] == id);
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddOrderScreen(
                            orderId: id,
                            shopName:
                                (order['shopName'] ?? order['shop'] ?? '').toString(),
                            wholesalerName: (order['wholesalerName'] ??
                                    order['wholesaler'] ??
                                    '')
                                .toString(),
                          ),
                        ),
                      );
                    },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever,
                  color: Colors.redAccent),
              title: const Text('Delete',
                  style: TextStyle(color: Colors.redAccent)),
              enabled: isManagerOrAdmin,
              onTap: !isManagerOrAdmin
                  ? null
                  : () async {
                      Navigator.pop(context);
                      await _safeRun(() => context
                          .read<AppDataProvider>()
                          .deleteOrder(id));
                    },
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

//// ===================== LIST VIEW =====================

class _ListViewSection extends StatelessWidget {
  const _ListViewSection({
    required this.pendingCounts,
    required this.orders,
    required this.isManagerOrAdmin,
    required this.myShop,
    required this.dateFmt,
    required this.onStartAdd,
    required this.onForward,
    required this.onReceived,
    required this.onDelete,
  });

  final Map<String, int> pendingCounts;
  final List<Map<String, dynamic>> orders;
  final bool isManagerOrAdmin;
  final String myShop;
  final DateFormat dateFmt;
  final VoidCallback onStartAdd;
  final Future<void> Function(String id) onForward;
  final Future<void> Function(String id) onReceived;
  final Future<void> Function(String id) onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (pendingCounts.isNotEmpty) ...[
          Text('Pending Orders from Wholesalers',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.white)),
          const SizedBox(height: 8),
          Card(
            elevation: 1,
            color: const Color(0xFF121A26),
            child: Column(
              children: pendingCounts.entries.map((e) {
                return ListTile(
                  title: Text(e.key,
                      style: const TextStyle(color: Colors.white)),
                  trailing: Text('x${e.value}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (orders.isEmpty) ...[
          const SizedBox(height: 80),
          const Center(
              child: Text('No orders found',
                  style: TextStyle(color: Colors.white70))),
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Order'),
              onPressed: onStartAdd,
            ),
          ),
        ] else ...[
          Row(
            children: [
              const Spacer(),
              Text('Showing ${orders.length}',
                  style: const TextStyle(color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 8),
          ...orders.map(
            (o) => _OrderCard(
              data: o,
              isManagerOrAdmin: isManagerOrAdmin,
              myShopName: myShop,
              dateFmt: dateFmt,
              onForward: onForward,
              onReceived: onReceived,
              onDelete: onDelete,
            ),
          ),
          const SizedBox(height: 100),
        ],
      ],
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
    required this.onDelete,
  });

  final Map<String, dynamic> data;
  final bool isManagerOrAdmin;
  final String myShopName;
  final DateFormat dateFmt;
  final Future<void> Function(String id) onForward;
  final Future<void> Function(String id) onReceived;
  final Future<void> Function(String id) onDelete;

  @override
  Widget build(BuildContext context) {
    final id = (data['id'] ?? '').toString();
    final uiStatus = (data['uiStatus'] ?? 'Ordered').toString();

    final wholesalerLabel =
        (data['wholesalerName'] ?? data['wholesaler'] ?? 'Wholesaler')
            .toString();
    final shopLabel = (data['shopName'] ?? data['shop'] ?? '-').toString();

    final amount = (data['amount'] is num)
        ? (data['amount'] as num).toDouble()
        : double.tryParse('${data['amount'] ?? 0}') ??
            0.0;

    final createdAtRaw = data['createdAt'];
    final createdAt = createdAtRaw is DateTime
        ? createdAtRaw
        : (createdAtRaw is Timestamp ? createdAtRaw.toDate() : null);

    final createdBy = (data['createdByName'] ?? '').toString();
    final note = (data['note'] ?? '').toString();
    final invoiceUrl = (data['invoiceUrl'] ?? '').toString();

    final belongsToMyShop = shopLabel == myShopName;

    final canForward = isManagerOrAdmin && uiStatus == 'Ordered';
    final canReceive = belongsToMyShop && uiStatus != 'Received';

    return Card(
      elevation: 1.5,
      color: const Color(0xFF121A26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                    wholesalerLabel,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                ),
                Text(
                  'Amount: ${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, color: Colors.white),
                ),
                if (isManagerOrAdmin) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: () => onDelete(id),
                    icon: const Icon(Icons.delete_forever,
                        color: Colors.redAccent),
                  ),
                ],
              ]),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.storefront,
                    size: 16, color: Colors.white70),
                const SizedBox(width: 6),
                Expanded(
                    child: Text('Shop: $shopLabel',
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(color: Colors.white70))),
                if (createdAt != null) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.access_time,
                      size: 16, color: Colors.white70),
                  const SizedBox(width: 4),
                  Text(dateFmt.format(createdAt),
                      style: const TextStyle(color: Colors.white70)),
                ],
              ]),
              const SizedBox(height: 6),
              if (createdBy.isNotEmpty)
                Text('By: $createdBy',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.white70)),
              if (note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Note: $note',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white70)),
                ),
              if (invoiceUrl.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.image,
                          size: 16, color: Colors.white70),
                      const SizedBox(width: 6),
                      const Text('Invoice attached',
                          style: TextStyle(
                              fontSize: 12, color: Colors.white70)),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => Dialog(
                              backgroundColor: const Color(0xFF0F1522),
                              child: InteractiveViewer(
                                child: Image.network(invoiceUrl,
                                    fit: BoxFit.contain),
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
                _StatusChip(status: uiStatus),
                const Spacer(),
                ElevatedButton(
                  onPressed: canForward ? () => onForward(id) : null,
                  child: const Text('Forward'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: canReceive ? () => onReceived(id) : null,
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
    late Color fg;
    switch (status) {
      case 'Forwarded':
        fg = Colors.orange;
        break;
      case 'Received':
        fg = Colors.green;
        break;
      default:
        fg = Colors.blueAccent;
    }
    final bg = fg.withOpacity(0.15);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.25)),
      ),
      child: Text(
        status,
        style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 12),
      ),
    );
  }
}

//// ===================== TABLE VIEW (ALL DATES) =====================

class _TableView extends StatelessWidget {
  const _TableView({
    required this.statusFilter,
    required this.onOpenActions,
    this.wholesalerFilter,
  });

  final String statusFilter;
  final String? wholesalerFilter;
  final void Function(Map<String, dynamic> row) onOpenActions;

  String _uiStatusOf(dynamic raw) {
    final s = (raw ?? 'Pending').toString();
    if (s == 'Received') return 'Received';
    if (s == 'Forwarded') return 'Forwarded';
    return 'Ordered';
  }

  Widget _tick(bool yes) => Icon(
        yes ? Icons.check_circle : Icons.cancel,
        size: 18,
        color: yes ? Colors.green : Colors.grey,
      );

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();
    final dateFmt = DateFormat('dd MMM yyyy');

    // Take all orders from provider (admin/manager => all; employee => scoped)
    List<Map<String, dynamic>> itemsAll = app.orders
        .map((m) => {...m, 'uiStatus': _uiStatusOf(m['status'])})
        .toList();

    // filter by status if needed
    if (statusFilter != 'All') {
      itemsAll = itemsAll
          .where((m) => (m['uiStatus'] as String) == statusFilter)
          .toList();
    }
    // filter by wholesaler if passed
    if ((wholesalerFilter ?? '').isNotEmpty) {
      final target = wholesalerFilter!.toLowerCase();
      itemsAll = itemsAll.where((m) {
        final w = (m['wholesalerName'] ?? m['wholesaler'] ?? '').toString();
        return w.toLowerCase() == target;
      }).toList();
    }

    // remove any Deleted if present locally
    itemsAll.removeWhere((m) => (m['status'] ?? '') == 'Deleted');

    // EMPLOYEE: limit to own last two only
    final role = (app.loggedInUser?['role'] ?? '').toString().toLowerCase();
    if (role == 'employee') {
      final myUid = (app.loggedInUser?['uid'] ?? '').toString();
      itemsAll = itemsAll
          .where((m) => (m['createdByUid'] ?? '') == myUid)
          .toList()
        ..sort((a, b) {
          final ad = a['createdAt'] is DateTime
              ? a['createdAt'] as DateTime
              : ((a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000));
          final bd = b['createdAt'] is DateTime
              ? b['createdAt'] as DateTime
              : ((b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000));
          return bd.compareTo(ad);
        });
      if (itemsAll.length > 2) {
        itemsAll = itemsAll.sublist(0, 2);
      }
    } else {
      // sort for admin/manager (desc)
      itemsAll.sort((a, b) {
        final ad = a['createdAt'] is DateTime
            ? a['createdAt'] as DateTime
            : ((a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000));
        final bd = b['createdAt'] is DateTime
            ? b['createdAt'] as DateTime
            : ((b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000));
        return bd.compareTo(ad);
      });
    }

    // group by wholesaler
    final Map<String, List<Map<String, dynamic>>> byWh = {};
    for (final m in itemsAll) {
      final w = (m['wholesalerName'] ?? m['wholesaler'] ?? '').toString();
      byWh.putIfAbsent(w, () => []).add(m);
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (itemsAll.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(
              child: Text('No orders found',
                  style: TextStyle(color: Colors.white70)),
            ),
          )
        else
          ...byWh.entries.map((entry) {
            final wholesalerName = entry.key.isEmpty ? 'Wholesaler' : entry.key;
            final list = entry.value;

            return Card(
              color: const Color(0xFF121A26),
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // top: wholesaler name
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C2535),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          wholesalerName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // table (Date + Shop + ticks + Actions)
                    LayoutBuilder(builder: (ctx, cs) {
                      final minTableWidth = 900.0;
                      final tableWidth = cs.maxWidth < minTableWidth
                          ? minTableWidth
                          : cs.maxWidth;

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: tableWidth),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              dividerColor: Colors.white12,
                            ),
                            child: DataTable(
                              columnSpacing: 24,
                              headingTextStyle: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w700),
                              dataTextStyle:
                                  const TextStyle(color: Colors.white),
                              columns: const [
                                DataColumn(label: Text('Date')),
                                DataColumn(label: Text('Shop')),
                                DataColumn(label: Text('Amount')),
                                DataColumn(label: Text('Ordered')),
                                DataColumn(label: Text('Forwarded')),
                                DataColumn(label: Text('Received')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: list.map((m) {
                                final dtRaw = m['createdAt'];
                                final dt = dtRaw is DateTime
                                    ? dtRaw
                                    : (dtRaw is Timestamp
                                        ? dtRaw.toDate()
                                        : null);
                                final dateStr =
                                    dt != null ? dateFmt.format(dt) : '-';

                                final shop =
                                    (m['shopName'] ?? m['shop'] ?? '')
                                        .toString();

                                final amount = (m['amount'] is num)
                                    ? (m['amount'] as num).toDouble()
                                    : double.tryParse('${m['amount'] ?? 0}') ??
                                        0.0;

                                final uiStatus =
                                    (m['uiStatus'] ?? 'Ordered').toString();

                                final isOrdered = uiStatus == 'Ordered';
                                final isForwarded = uiStatus == 'Forwarded';
                                final isReceived = uiStatus == 'Received';

                                return DataRow(
                                  cells: [
                                    DataCell(Text(dateStr)),
                                    DataCell(Text(shop)),
                                    DataCell(Text(amount.toStringAsFixed(2))),
                                    DataCell(Center(child: _tick(isOrdered))),
                                    DataCell(Center(child: _tick(isForwarded))),
                                    DataCell(Center(child: _tick(isReceived))),
                                    DataCell(
                                      IconButton(
                                        tooltip: 'Actions',
                                        onPressed: () => onOpenActions(m),
                                        icon: const Icon(
                                          Icons.more_horiz,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
