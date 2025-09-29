// ignore_for_file: use_build_context_synchronously
// lib/screens/wholesaler_drilldown_screen.dart

import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/app_data_provider.dart';
import 'add_order_screen.dart';

/// ======= THEME TOKENS (dark only) =======
const _brandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF6D60F7), Color(0xFF5AD7FF), Color(0xFF00E18B)],
);
const _neon = Color(0xFF16FFC6);
const _glassFill = Color(0x1AFFFFFF);
const _glassStroke = Color(0x33FFFFFF);

final _dateFmt = DateFormat('dd MMM yyyy, hh:mm a');
final _amtFmtCompact =
    NumberFormat.compactCurrency(symbol: '', decimalDigits: 0);

/// =============== PUBLIC SCREEN ===========================
class WholesalerDrilldownScreen extends StatefulWidget {
  final String? initialQuery;
  const WholesalerDrilldownScreen({super.key, this.initialQuery});

  @override
  State<WholesalerDrilldownScreen> createState() =>
      _WholesalerDrilldownScreenState();
}

class _WholesalerDrilldownScreenState extends State<WholesalerDrilldownScreen> {
  String _query = '';
  _WSFilter _filter = _WSFilter.all;

  // ✅ Stable search infra to prevent keyboard flicker
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;

  (int cols, double aspect, double gap) _gridForWidth(double w) {
    if (w >= 1600) return (4, 1.35, 16);
    if (w >= 1200) return (3, 1.35, 16);
    if (w >= 800) return (2, 1.35, 14);
    return (1, 2.9, 12);
  }

  @override
  void initState() {
    super.initState();
    final s = (widget.initialQuery ?? '').trim();
    if (s.isNotEmpty) {
      _query = s;
      _searchCtrl.text = s;
    }
    _searchCtrl.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), () {
        if (mounted) setState(() => _query = _searchCtrl.text.trim());
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _openAddWholesaler() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F1B2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => const _AddWholesalerSheet(),
    );
  }

  // ✅ Fetch names on the fly (ActionsRow ko stream par depend nahi rakha)
  Future<void> _openAddPayment({String? preselect}) async {
    final snap = await FirebaseFirestore.instance
        .collection('wholesalers')
        .where('isActive', isEqualTo: true)
        .get();
    final names = snap.docs
        .map((d) => ((d.data())['name'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList()
      ..sort();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F1B2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _AddPaymentSheet(
        wholesalerNames: names,
        preselect: preselect,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();
    final role =
        (app.loggedInUser?['role'] ?? '').toString().toLowerCase().trim();
    final canManage = role == 'admin' || role == 'manager';

    return Scaffold(
      appBar: const _NeonGlassAppBar(title: 'Wholesalers'),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-0.7, -1),
            end: Alignment(1, 0.7),
            colors: [Color(0xFF0A1220), Color(0xFF0E1A2C), Color(0xFF0A1120)],
          ),
        ),
        child: LayoutBuilder(builder: (ctx, cs) {
          final (cols, aspect, gap) = _gridForWidth(cs.maxWidth);
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              children: [
                // 🔴 Search + Filters OUTSIDE stream (no focus loss)
                _TopSearchAndFilters(
                  controller: _searchCtrl,
                  focusNode: _searchFocus,
                  selected: _filter,
                  onFilterChanged: (f) => setState(() => _filter = f),
                ),
                const SizedBox(height: 10),
                if (canManage)
                  _ActionsRow(
                    onAddWholesaler: _openAddWholesaler,
                    onAddPayment: () => _openAddPayment(),
                  ),
                if (canManage) const SizedBox(height: 12),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('wholesalers')
                        .where('isActive', isEqualTo: true)
                        .snapshots(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator(color: _neon));
                      }
                      final docs = (snap.data?.docs ?? [])
                          .map((d) => Wholesaler.fromMap(d.id, d.data()))
                          .toList();

                      // search
                      final q = _query.toLowerCase();
                      final filteredByQuery = q.isEmpty
                          ? docs
                          : docs
                              .where((w) =>
                                  w.name.toLowerCase().contains(q) ||
                                  (w.phone ?? '').toLowerCase().contains(q))
                              .toList();

                      // quick filters (netDue from opening + totals if available)
                      final list = switch (_filter) {
                        _WSFilter.all => filteredByQuery,
                        _WSFilter.due =>
                          filteredByQuery.where((w) => w.netDue > 0.001).toList(),
                        _WSFilter.advance =>
                          filteredByQuery.where((w) => w.netDue < -0.001).toList(),
                        _WSFilter.settled =>
                          filteredByQuery
                              .where((w) => w.netDue.abs() <= 0.001)
                              .toList(),
                        _WSFilter.inactive => filteredByQuery.where((w) {
                            final last = w.lastActivity;
                            if (last == null) return true;
                            return DateTime.now().difference(last).inDays > 30;
                          }).toList(),
                      };

                      return GridView.builder(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisSpacing: gap,
                          crossAxisSpacing: gap,
                          childAspectRatio: aspect,
                        ),
                        itemCount: list.length,
                        itemBuilder: (_, i) => _WholesalerCard(
                          w: list[i],
                          onOpen: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => WholesalerDetailScreen(
                                  wholesaler: list[i],
                                ),
                              ),
                            );
                          },
                          onDelete: !canManage
                              ? null
                              : () async {
                                  final ok =
                                      await _confirmDelete(context, list[i]);
                                  if (ok == true) {
                                    await FirebaseFirestore.instance
                                        .collection('wholesalers')
                                        .doc(list[i].id)
                                        .delete();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              'Deleted ${list[i].name} successfully')),
                                    );
                                  }
                                },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, Wholesaler w) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F1B2C),
        title: const Text('Delete wholesaler?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'This will remove "${w.name}". Records in orders/payments remain. Continue?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
  }
}

/// =============== MODEL ==============================
class Wholesaler {
  final String id;
  final String name;
  final String? phone;
  final double totalPurchases;
  final double totalPayments;
  final double openingBalance; // +ve due, -ve advance
  final DateTime? lastActivity;

  const Wholesaler({
    required this.id,
    required this.name,
    this.phone,
    required this.totalPurchases,
    required this.totalPayments,
    required this.openingBalance,
    this.lastActivity,
  });

  double get netDue => (openingBalance + totalPurchases - totalPayments);

  factory Wholesaler.fromMap(String id, Map<String, dynamic> m) {
    double toD(v) =>
        (v is num) ? v.toDouble() : double.tryParse('${v ?? 0}') ?? 0.0;
    DateTime? toT(v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return Wholesaler(
      id: id,
      name: (m['name'] ?? m['wholesaler'] ?? 'Unnamed').toString(),
      phone: (m['phone'] ?? m['contact'])?.toString(),
      totalPurchases: toD(m['totalPurchases']),
      totalPayments: toD(m['totalPayments']),
      openingBalance: toD(m['openingBalance']),
      lastActivity: toT(m['updatedAt'] ?? m['lastActivity']),
    );
  }
}

/// ===== Search + Filters (kept OUTSIDE stream) =====
enum _WSFilter { all, due, advance, settled, inactive }

class _TopSearchAndFilters extends StatelessWidget {
  const _TopSearchAndFilters({
    required this.controller,
    required this.focusNode,
    required this.selected,
    required this.onFilterChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final _WSFilter selected;
  final ValueChanged<_WSFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, _WSFilter value) {
      final isSel = selected == value;
      return InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => onFilterChanged(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withValues(alpha: isSel ? 0.14 : 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: isSel ? FontWeight.w800 : FontWeight.w600)),
              if (isSel)
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  height: 3,
                  width: 36,
                  decoration: const BoxDecoration(
                    gradient: _brandGradient,
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 480;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: isNarrow ? width : 360,
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.search,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: const Color(0x14FFFFFF),
                hintText: 'Search...',
                hintStyle: const TextStyle(color: Colors.white70),
                prefixIcon:
                    const Icon(Icons.search_rounded, color: Colors.white70),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear',
                        onPressed: () {
                          controller.clear();
                          focusNode.requestFocus(); // keep keyboard up
                        },
                        icon: const Icon(Icons.clear, color: Colors.white70),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.only(top: 12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            chip('All', _WSFilter.all),
            chip('Due', _WSFilter.due),
            chip('Advance', _WSFilter.advance),
            chip('Settled', _WSFilter.settled),
            chip('Inactive', _WSFilter.inactive),
          ],
        ),
      ],
    );
  }
}

/// =============== ACTIONS ROW =========================
class _ActionsRow extends StatelessWidget {
  final VoidCallback onAddWholesaler;
  final VoidCallback onAddPayment;
  const _ActionsRow({required this.onAddWholesaler, required this.onAddPayment});

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, String label, VoidCallback onTap) {
      return Expanded(
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        btn(Icons.store_mall_directory_rounded, 'Add Wholesaler', onAddWholesaler),
        const SizedBox(width: 10),
        btn(Icons.payments_rounded, 'Add Payment', onAddPayment),
      ],
    );
  }
}

/// =============== WHOLESALER CARD ======================
class _WholesalerCard extends StatelessWidget {
  final Wholesaler w;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;
  const _WholesalerCard(
      {required this.w, required this.onOpen, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _glassFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _glassStroke),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 14)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpen,
            splashColor: _neon.withValues(alpha: 0.12),
            highlightColor: Colors.white.withValues(alpha: 0.10),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _brandGradient,
                    ),
                    child: const Icon(Icons.storefront_rounded,
                        color: Colors.black87),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      w.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15),
                    ),
                  ),
                  if (onDelete != null)
                    IconButton(
                      tooltip: 'Delete wholesaler',
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_forever,
                          color: Colors.redAccent),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// =============== DETAIL SCREEN =========================
class WholesalerDetailScreen extends StatelessWidget {
  final Wholesaler wholesaler;
  const WholesalerDetailScreen({super.key, required this.wholesaler});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();
    final role =
        (app.loggedInUser?['role'] ?? '').toString().toLowerCase().trim();
    final canManage = role == 'admin' || role == 'manager';
    final w = wholesaler;

    return Scaffold(
      appBar: _NeonGlassAppBar(
        title: w.name,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        ),
        trailing: canManage
            ? IconButton(
                tooltip: 'Add Order',
                onPressed: () async {
                  await _startAddOrderFlow(context, w.name);
                },
                icon: const Icon(Icons.add_shopping_cart, color: _neon),
              )
            : null,
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _openAddPaymentSheetFor(context, w.name),
              icon: const Icon(Icons.payments),
              label: const Text('Add Payment'),
            )
          : null,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-0.7, -1),
            end: Alignment(1, 0.7),
            colors: [Color(0xFF0A1220), Color(0xFF0E1A2C), Color(0xFF0A1120)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            children: [
              _SummaryHeader(w: w),
              const SizedBox(height: 12),
              Expanded(
                  child:
                      _OrdersAndPaymentsTabs(w: w, canManage: canManage)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAddPaymentSheetFor(
      BuildContext context, String name) async {
    final snap =
        await FirebaseFirestore.instance.collection('wholesalers').get();
    final names = snap.docs
        .map((d) =>
            ((d.data())['name'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList()
      ..sort();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F1B2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _AddPaymentSheet(
        wholesalerNames: names,
        preselect: name,
      ),
    );
  }

  Future<void> _startAddOrderFlow(
      BuildContext context, String wholesalerName) async {
    final app = context.read<AppDataProvider>();
    final shops = app.shops
        .where((s) => (s['isDeleted'] ?? false) != true)
        .map((s) => {
              'id': (s['id'] ?? s['docId'] ?? '').toString(),
              'name': (s['name'] ?? '').toString()
            })
        .where((m) => (m['name'] ?? '').toString().isNotEmpty)
        .toList();

    if (shops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No shops found. Please add a shop first.')),
      );
      return;
    }

    final chosen = await showModalBottomSheet<Map<String, String>>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: ListView.separated(
          itemCount: shops.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final s = shops[i];
            return ListTile(
              leading: const Icon(Icons.store, color: Colors.white),
              title:
                  Text(s['name']!, style: const TextStyle(color: Colors.white)),
              tileColor: const Color(0x15000000),
              onTap: () => Navigator.pop(context, s),
            );
          },
        ),
      ),
    );
    if (chosen == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddOrderScreen(
          shopName: chosen['name']!,
          wholesalerName: wholesalerName,
        ),
      ),
    );
  }
}

class _OrdersAndPaymentsTabs extends StatefulWidget {
  final Wholesaler w;
  final bool canManage;
  const _OrdersAndPaymentsTabs({required this.w, required this.canManage});
  @override
  State<_OrdersAndPaymentsTabs> createState() =>
      _OrdersAndPaymentsTabsState();
}

class _OrdersAndPaymentsTabsState extends State<_OrdersAndPaymentsTabs>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.w;
    final canManage = widget.canManage;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: _glassFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _glassStroke),
          ),
          child: TabBar(
            controller: _tab,
            indicator: const UnderlineTabIndicator(
              borderSide: BorderSide(color: _neon, width: 3),
              insets: EdgeInsets.symmetric(horizontal: 18),
            ),
            labelStyle: const TextStyle(fontWeight: FontWeight.w800),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Orders'),
              Tab(text: 'Payments'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _OverviewTab(w: w),
              _OrdersTable(w: w, canManage: canManage),
              _PaymentsTable(w: w, canManage: canManage),
            ],
          ),
        ),
      ],
    );
  }
}

/// ======= SUMMARY HEADER =======
class _SummaryHeader extends StatelessWidget {
  final Wholesaler w;
  const _SummaryHeader({required this.w});

  @override
  Widget build(BuildContext context) {
    String fmt(double v) => v.abs() >= 1e6
        ? '${(v / 1e6).toStringAsFixed(1)}M'
        : v.toStringAsFixed(0);

    Widget metric(String title, String val) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 6),
              Text(val,
                  style: const TextStyle(
                      color: _neon,
                      fontWeight: FontWeight.w900,
                      fontSize: 18)),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        metric('Purchases', fmt(w.totalPurchases)),
        const SizedBox(width: 10),
        metric('Payments', fmt(w.totalPayments)),
        const SizedBox(width: 10),
        metric(w.netDue >= 0 ? 'Net Due' : 'Advance', fmt(w.netDue.abs())),
      ],
    );
  }
}

/// ======= OVERVIEW TAB =======
class _OverviewTab extends StatelessWidget {
  final Wholesaler w;
  const _OverviewTab({required this.w});

  @override
  Widget build(BuildContext context) {
    String fmt(double v) => v.abs() >= 1e6
        ? '${(v / 1e6).toStringAsFixed(1)}M'
        : v.toStringAsFixed(0);

    Widget metric(String title, String value) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    color: _neon,
                    fontWeight: FontWeight.w900,
                    fontSize: 18)),
          ],
        ),
      );
    }

    final width = MediaQuery.of(context).size.width;
    final cross = width >= 800 ? 3 : 2;

    return GridView.count(
      crossAxisCount: cross,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        metric('Total Purchases', fmt(w.totalPurchases)),
        metric('Total Payments', fmt(w.totalPayments)),
        metric(w.netDue >= 0 ? 'Net Due' : 'Advance', fmt(w.netDue.abs())),
      ],
    );
  }
}

/// ======= ORDERS TABLE =======
class _OrdersTable extends StatelessWidget {
  final Wholesaler w;
  final bool canManage;
  const _OrdersTable({required this.w, required this.canManage});

  @override
  Widget build(BuildContext context) {
    final col = FirebaseFirestore.instance.collection('orders');
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: col
          .where('wholesalerName', isEqualTo: w.name)
          .orderBy('createdAt', descending: true) // ✅ latest first
          .snapshots(),
      builder: (c, s) {
        if (s.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _neon));
        }
        final items = s.data?.docs ?? [];
        if (items.isEmpty) {
          return const _EmptyState(
              text: 'No orders found for this wholesaler.');
        }

        DataRow row(QueryDocumentSnapshot<Map<String, dynamic>> d) {
          final m = d.data();
          final raw = m['createdAt'];
          final dt = raw is Timestamp
              ? raw.toDate()
              : (raw is DateTime ? raw : DateTime.tryParse('$raw'));
          final dateStr = dt != null ? _dateFmt.format(dt) : '-';
          final amountNum =
              (m['amount'] ?? m['invoiceAmount'] ?? 0);
          final amountStr = _amtFmtCompact.format(
              amountNum is num ? amountNum : double.tryParse('$amountNum') ?? 0);
          final shop = (m['shopName'] ?? m['shop'] ?? '').toString();
          final status = (m['status'] ?? 'Pending').toString();

          return DataRow(
            cells: [
              DataCell(Text(dateStr,
                  style: const TextStyle(color: Colors.white))),
              DataCell(
                  Text(shop, style: const TextStyle(color: Colors.white))),
              DataCell(Text(status,
                  style: const TextStyle(color: Colors.white))),
              DataCell(
                  Text(amountStr, style: const TextStyle(color: _neon))),
              DataCell(
                canManage
                    ? IconButton(
                        tooltip: 'Delete order',
                        onPressed: () async {
                          await d.reference.delete();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Order deleted')),
                          );
                        },
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          );
        }

        return _GlassTableWrapper(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingTextStyle: const TextStyle(
                  color: Colors.white70, fontWeight: FontWeight.w700),
              dataTextStyle: const TextStyle(color: Colors.white),
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Shop')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Amount')),
                DataColumn(label: Text('')),
              ],
              rows: items.map(row).toList(),
            ),
          ),
        );
      },
    );
  }
}

/// ======= PAYMENTS TABLE =======
class _PaymentsTable extends StatelessWidget {
  final Wholesaler w;
  final bool canManage;
  const _PaymentsTable({required this.w, required this.canManage});

  @override
  Widget build(BuildContext context) {
    final payments = FirebaseFirestore.instance.collection('payments');
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: payments
          .where('toWholesalerName', isEqualTo: w.name)
          .orderBy('createdAt', descending: true) // ✅ latest first
          .snapshots(),
      builder: (c, s) {
        if (s.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _neon));
        }
        final items = s.data?.docs ?? [];
        if (items.isEmpty) {
          return const _EmptyState(
              text: 'No payments recorded for this wholesaler.');
        }

        DataRow row(QueryDocumentSnapshot<Map<String, dynamic>> d) {
          final m = d.data();
          final raw = m['createdAt'];
          final dt = raw is Timestamp
              ? raw.toDate()
              : (raw is DateTime ? raw : DateTime.tryParse('$raw'));
          final dateStr = dt != null ? _dateFmt.format(dt) : '-';
          final shop = (m['shopName'] ?? '').toString();
          final amountNum = (m['amount'] ?? 0);
          final amountStr = _amtFmtCompact.format(
              amountNum is num ? amountNum : double.tryParse('$amountNum') ?? 0);
          final mode = (m['mode'] ?? m['method'] ?? '-').toString();

          return DataRow(
            cells: [
              DataCell(Text(dateStr,
                  style: const TextStyle(color: Colors.white))),
              DataCell(
                  Text(shop, style: const TextStyle(color: Colors.white))),
              DataCell(
                  Text(mode, style: const TextStyle(color: Colors.white))),
              DataCell(
                  Text(amountStr, style: const TextStyle(color: _neon))),
              DataCell(
                canManage
                    ? IconButton(
                        tooltip: 'Delete payment',
                        onPressed: () async {
                          await d.reference.delete();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Payment deleted')),
                          );
                        },
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          );
        }

        return _GlassTableWrapper(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingTextStyle: const TextStyle(
                  color: Colors.white70, fontWeight: FontWeight.w700),
              dataTextStyle: const TextStyle(color: Colors.white),
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Shop')),
                DataColumn(label: Text('Mode')),
                DataColumn(label: Text('Amount')),
                DataColumn(label: Text('')),
              ],
              rows: items.map(row).toList(),
            ),
          ),
        );
      },
    );
  }
}

/// =============== GLASS TABLE WRAPPER ====================
class _GlassTableWrapper extends StatelessWidget {
  final Widget child;
  const _GlassTableWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: child,
    );
  }
}

/// =============== SHARED SMALL WIDGETS ===================
class _NeonGlassAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String title;
  final Widget? trailing;
  final Widget? leading;
  const _NeonGlassAppBar({required this.title, this.trailing, this.leading});
  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      child: Container(
        height: preferredSize.height - 8,
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _glassFill,
          border: Border.all(color: _glassStroke),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
                color: Color(0x3300FFC6),
                blurRadius: 22,
                offset: Offset(0, 8)),
            BoxShadow(
                color: Color(0x33000000),
                blurRadius: 22,
                offset: Offset(0, 14)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Row(
              children: [
                leading ??
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white),
                    ),
                const SizedBox(width: 4),
                Expanded(
                  child: ShaderMask(
                    shaderCallback: (r) => _brandGradient.createShader(r),
                    child: Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18)),
                  ),
                ),
                trailing ?? const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState({required this.text});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ShaderMask(
            shaderCallback: (r) => _brandGradient.createShader(r),
            child: const Icon(Icons.inbox_rounded,
                size: 48, color: Colors.white)),
        const SizedBox(height: 10),
        Text(text, style: const TextStyle(color: Colors.white70)),
      ]),
    );
  }
}

/// ====== Add Wholesaler Sheet ======
class _AddWholesalerSheet extends StatefulWidget {
  const _AddWholesalerSheet();
  @override
  State<_AddWholesalerSheet> createState() => _AddWholesalerSheetState();
}

class _AddWholesalerSheetState extends State<_AddWholesalerSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _opening = TextEditingController(); // +ve due, −ve advance
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _opening.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add Wholesaler',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          _glassField(controller: _name, label: 'Name *'),
          const SizedBox(height: 8),
          _glassField(controller: _phone, label: 'Phone'),
          const SizedBox(height: 8),
          _glassField(
              controller: _opening,
              label: 'Opening Balance (+due, −advance)',
              keyboard: TextInputType.number),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          final name = _name.text.trim();
                          final opening = double.tryParse(_opening.text
                                      .trim()
                                      .replaceAll(',', '')) ??
                                  0;
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Name required')));
                            return;
                          }
                          setState(() => _saving = true);
                          await FirebaseFirestore.instance
                              .collection('wholesalers')
                              .add({
                            'name': name,
                            'nameLower': name.toLowerCase(),
                            'phone': _phone.text.trim().isEmpty
                                ? null
                                : _phone.text.trim(),
                            'openingBalance': opening,
                            'totalPurchases': 0.0,
                            'totalPayments': 0.0,
                            'isActive': true,
                            'createdAt': FieldValue.serverTimestamp(),
                            'updatedAt': FieldValue.serverTimestamp(),
                          });
                          Navigator.pop(context);
                        },
                  child: _saving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save'),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _glassField(
      {required TextEditingController controller,
      required String label,
      TextInputType? keyboard}) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: _neon),
        ),
      ),
    );
  }
}

/// ====== Add Payment Sheet (uses AppDataProvider.recordWholesalerPayment) ======
class _AddPaymentSheet extends StatefulWidget {
  final List<String> wholesalerNames;
  final String? preselect;
  const _AddPaymentSheet({required this.wholesalerNames, this.preselect});

  @override
  State<_AddPaymentSheet> createState() => _AddPaymentSheetState();
}

class _AddPaymentSheetState extends State<_AddPaymentSheet> {
  String? _party;
  String? _shop;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _mode = 'Cash';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _party = widget.preselect;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();
    final shops = app.shops
        .where((s) => (s['isDeleted'] ?? false) != true)
        .map((s) => (s['name'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList()
      ..sort();

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Payment',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _party,
              items: widget.wholesalerNames
                  .map((n) => DropdownMenuItem(
                        value: n,
                        child: Text(n,
                            style: const TextStyle(color: Colors.white)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _party = v),
              decoration: _glassDropDecoration('Wholesaler *'),
              dropdownColor: const Color(0xFF0F1B2C),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _shop,
              items: shops
                  .map((n) => DropdownMenuItem(
                        value: n,
                        child: Text(n,
                            style: const TextStyle(color: Colors.white)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _shop = v),
              decoration: _glassDropDecoration('Shop *'),
              dropdownColor: const Color(0xFF0F1B2C),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            _glassText('Amount *',
                controller: _amount, keyboard: TextInputType.number),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _mode,
              items: const ['Cash', 'Bank', 'Card', 'Online']
                  .map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(m,
                            style: const TextStyle(color: Colors.white)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _mode = v ?? 'Cash'),
              decoration: _glassDropDecoration('Mode'),
              dropdownColor: const Color(0xFF0F1B2C),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            _glassText('Note', controller: _note),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving
                        ? null
                        : () async {
                            final p = _party ?? '';
                            final shop = _shop ?? '';
                            final amt = double.tryParse(_amount.text
                                        .trim()
                                        .replaceAll(',', '')) ??
                                0;
                            if (p.isEmpty || shop.isEmpty || amt <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Select wholesaler, shop & amount')));
                              return;
                            }
                            setState(() => _saving = true);
                            // Save through provider so schema stays consistent
                            await context
                                .read<AppDataProvider>()
                                .recordWholesalerPayment(
                                  shopName: shop,
                                  wholesalerName: p,
                                  amount: amt,
                                  note: _note.text.trim().isEmpty
                                      ? null
                                      : _note.text.trim(),
                                  mode: _mode, // ✅ pass mode
                                );
                            Navigator.pop(context);
                          },
                    child: _saving
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _glassDropDecoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: _neon),
        ),
      );

  Widget _glassText(String label,
      {required TextEditingController controller, TextInputType? keyboard}) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: _neon),
        ),
      ),
    );
  }
}
