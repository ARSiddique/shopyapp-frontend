// lib/screens/sales_screen.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../providers/app_data_provider.dart';
import 'add_sale_screen.dart';
import 'shop_selection_screen.dart';

/// ---------- Per-day row model ----------
class _DayRow {
  _DayRow({required this.shop, required this.day});
  final String shop;
  final DateTime day; // midnight
  double cash = 0.0;
  double card = 0.0;
  double other = 0.0;
  double total = 0.0;
  String? employee;     // last for that day
  DateTime? lastSaleAt; // not printed in table (we show day)
}

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});
  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  // ---- Filters ----
  String _period = 'Weekly';      // default Weekly (requested)
  String _selectedShop = 'All';   // will auto-pick first shop on first build
  DateTime _anchorDate = DateTime.now();
  DateTimeRange? _range;

  // cutoff highlight (no-sale today after this hour)
  final int _cutoffHour = 21;

  // export cache
  List<_DayRow> _exportRows = [];
  DateTime? _lastFrom;
  DateTime? _lastTo;

  bool _bootstrapped = false; // pick first shop once

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();

    final shops = app.shops
        .where((s) => (s['isDeleted'] ?? false) != true)
        .map((s) => (s['name'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList()
      ..sort();

    // default to first shop once (specific shop + weekly by default)
    if (!_bootstrapped && shops.isNotEmpty) {
      _bootstrapped = true;
      _selectedShop = shops.first;
      _period = 'Weekly';
    }

    final allShopOptions = ['All', ...shops];

    if (_selectedShop != 'All' && !shops.contains(_selectedShop)) {
      _selectedShop = 'All';
    }

    final visibleShops = (_selectedShop != 'All' && shops.contains(_selectedShop))
        ? <String>[_selectedShop]
        : shops;

    final (from, to) = _computeRange(); // [from .. to) exclusive
    final periodLabel = _labelForRange(from, to);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales'),
        leading: const BackButton(),
        actions: [
          IconButton(
            tooltip: 'Export PDF',
            onPressed: _exportPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: 'Export CSV',
            onPressed: _exportCsv,
            icon: const Icon(Icons.table_chart_outlined),
          ),
          // Add Sale: Admin/Manager -> shop hub, Employee -> direct form
          IconButton(
            tooltip: 'Add Sale',
            onPressed: () {
              final app = context.read<AppDataProvider>();
              final isAdminOrManager = app.isAdmin || app.isManager;
              if (isAdminOrManager) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ShopSelectionScreen(next: NextAction.actions),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddSaleScreen()),
                );
              }
            },
            icon: const Icon(Icons.add),
          ),
          // Admin/Manager: compute day from transactions
          Builder(
            builder: (ctx) {
              final app = ctx.watch<AppDataProvider>();
              final canCompute = (app.isAdmin == true) || (app.isManager == true);
              if (!canCompute) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Daily Sale from Transactions',
                icon: const Icon(Icons.calculate_outlined),
                onPressed: () {
                  showModalBottomSheet(
                    context: ctx,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (_) => const _DailySaleFromTransactionsSheet(),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 6),
          _filtersRow(allShopOptions, periodLabel),
          const SizedBox(height: 6),
          Expanded(
            child: _tableStream(
              from: from,
              to: to,
              selectedShop: _selectedShop,
              allShops: visibleShops,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------- FILTERS ROW (compact) ---------------------
  Widget _filtersRow(List<String> shopOptions, String periodLabel) {
    final theme = Theme.of(context);
    final isRange = _period == 'Date Range';
    final isSpecific = _period == 'Specific Date';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<String>(
                isDense: true,
                value: shopOptions.contains(_selectedShop) ? _selectedShop : 'All',
                items: shopOptions
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedShop = v ?? 'All'),
                decoration: const InputDecoration(
                  labelText: 'Shop',
                  isDense: true,
                  border: UnderlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<String>(
                isDense: true,
                value: _period,
                items: const [
                  DropdownMenuItem(value: 'Daily', child: Text('Daily')),
                  DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                  DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
                  DropdownMenuItem(value: 'Yearly', child: Text('Yearly')),
                  DropdownMenuItem(value: 'Specific Date', child: Text('Specific Date')),
                  DropdownMenuItem(value: 'Date Range', child: Text('Date Range')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _period = v;
                    if (_period != 'Date Range') _range = null;
                  });
                  Future.microtask(() async {
                    if (!mounted) return;
                    if (_period == 'Specific Date') {
                      await _pickAnchorDate();
                    } else if (_period == 'Date Range') {
                      await _pickRange();
                    }
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Period',
                  isDense: true,
                  border: UnderlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            if (isRange)
              _rangePickerButton(theme)
            else
              _datePickerButton(theme, periodLabel, isSpecific),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }

  Widget _datePickerButton(ThemeData theme, String periodLabel, bool isSpecific) {
    final btnLabel = isSpecific ? 'Pick date' : 'Anchor date';
    return OutlinedButton.icon(
      icon: const Icon(Icons.event, size: 18),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(btnLabel),
          const SizedBox(width: 6),
          Text(
            periodLabel,
            style: TextStyle(
              fontSize: 12,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
      onPressed: _pickAnchorDate,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    );
  }

  Widget _rangePickerButton(ThemeData theme) {
    final label = (_range == null)
        ? 'Pick range'
        : '${DateFormat('dd MMM, yyyy').format(_range!.start)}  –  ${DateFormat('dd MMM, yyyy').format(_range!.end)}';
    return OutlinedButton.icon(
      icon: const Icon(Icons.date_range, size: 18),
      label: Text(label),
      onPressed: _pickRange,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    );
  }

  Future<void> _pickAnchorDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchorDate,
      firstDate: DateTime(2022, 1, 1),
      lastDate: DateTime(now.year, now.month, now.day), // future blocked
    );
    if (picked != null) setState(() => _anchorDate = picked);
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _range ??
          DateTimeRange(
            start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6)),
            end: DateTime(now.year, now.month, now.day),
          ),
      firstDate: DateTime(2022, 1, 1),
      lastDate: DateTime(now.year, now.month, now.day), // future blocked
    );
    if (picked != null) setState(() => _range = picked);
  }

  // --------------------- DATA TABLE ---------------------
  Widget _tableStream({
    required DateTime from,
    required DateTime to,
    required String selectedShop,
    required List<String> allShops,
  }) {
    final app = context.read<AppDataProvider>();
    final bool filterByShop = selectedShop != 'All';

    final q = app.buildSalesQuery(
      from: from,
      to: to,
      shop: filterByShop ? selectedShop : null,
    );

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (ctx, snap) {
        if (snap.hasError) {
          final err = snap.error;
          if (err is FirebaseException && err.code == 'failed-precondition') {
            final loose = app.buildSalesQueryLoose(
              shop: filterByShop ? selectedShop : null,
            );
            return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
              future: loose.get(),
              builder: (ctx, fs) {
                if (fs.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (fs.hasError) return Center(child: Text('Error: ${fs.error}'));
                final docs = fs.data?.docs ?? const [];
                final rows = _rowsPerDay(
                  docs.map((d) => app.mapSaleDoc(d)).where((m) {
                    final dt = m['createdAt'] as DateTime;
                    return !dt.isBefore(from) && dt.isBefore(to);
                  }).toList(),
                  allShops,
                  from,
                  to,
                );
                return _buildTablePerDay(rows);
              },
            );
          }
          return Center(child: Text('Error: $err'));
        }

        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snap.data!.docs;
        final rows = _rowsPerDay(
          docs.map((d) => app.mapSaleDoc(d)).toList(),
          allShops,
          from,
          to,
        );
        return _buildTablePerDay(rows);
      },
    );
  }

  List<_DayRow> _rowsPerDay(
    List<Map<String, dynamic>> sales,
    List<String> visibleShops,
    DateTime from,
    DateTime to,
  ) {
    final byKey = <String, _DayRow>{};

    // Initialize blank rows for each day × each shop so missing days show
    for (int i = 0; i < to.difference(from).inDays; i++) {
      final day = DateTime(from.year, from.month, from.day).add(Duration(days: i));
      for (final shop in visibleShops) {
        final key = '${shop}_${DateFormat('yyyy-MM-dd').format(day)}';
        byKey[key] = _DayRow(shop: shop, day: day);
      }
    }

    // Fill from sales
    for (final m in sales) {
      final shop = (m['shop'] ?? '').toString();
      if (!visibleShops.contains(shop)) continue;

      final dt = (m['createdAt'] as DateTime?) ?? DateTime.now();
      final day = DateTime(dt.year, dt.month, dt.day);
      if (day.isBefore(from) || !day.isBefore(to)) continue;

      final key = '${shop}_${DateFormat('yyyy-MM-dd').format(day)}';
      final row = byKey[key] ?? _DayRow(shop: shop, day: day);

      double d(v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
      final cash = d(m['cash']), card = d(m['card']), other = d(m['other']);
      final total = d(m['total'] ?? (cash + card + other));

      row.cash += cash; row.card += card; row.other += other; row.total += total;

      final emp = (m['employee'] ?? m['addedBy'] ?? '').toString();
      if (row.lastSaleAt == null || dt.isAfter(row.lastSaleAt!)) {
        row.lastSaleAt = dt; row.employee = emp;
      }
      byKey[key] = row;
    }

    final rows = byKey.values.toList()
      ..sort((a, b) {
        final c = b.day.compareTo(a.day); // latest day first
        if (c != 0) return c;
        return a.shop.compareTo(b.shop);
      });
    return rows;
  }

  Widget _buildTablePerDay(List<_DayRow> rows) {
    _exportRows = rows;
    if (rows.isNotEmpty) {
      _lastFrom = rows.last.day;
      _lastTo = rows.first.day.add(const Duration(days: 1));
    } else {
      _lastFrom = null;
      _lastTo = null;
    }

    final now = DateTime.now();
    final app = context.read<AppDataProvider>();
    final canEditDelete = (app.isAdmin == true) || (app.isManager == true);

    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 760),
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontSize: 12, height: 1.0),
            child: DataTableTheme(
              data: const DataTableThemeData(
                dataRowMinHeight: 10,
                dataRowMaxHeight: 24,
                headingRowHeight: 26,
                dividerThickness: 0.3,
              ),
              child: DataTable(
                // a little left padding but compact
                horizontalMargin: 8,      // <<< small left/right inset
                columnSpacing: 0,         // <<< columns tight

                // ======== HEADINGS (Date first) ========
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Shop')),
                  DataColumn(label: Text('Total')),
                  DataColumn(label: Text('Cash')),
                  DataColumn(label: Text('Card')),
                  DataColumn(label: Text('Other')),
                  DataColumn(label: Text('Employee')),
                  DataColumn(label: Text('Actions')),
                ],

                // ======== ROWS (Date first) ========
                rows: rows.map((r) {
                  final isToday = DateUtils.isSameDay(r.day, DateTime.now());
                  final hasSale = (r.total > 0) || (r.cash > 0) || (r.card > 0) || (r.other > 0);
                  final style = TextStyle(
                    color: (isToday && !hasSale) ? Colors.red.shade700 : null,
                    fontWeight: (isToday && !hasSale) ? FontWeight.w600 : FontWeight.w400,
                  );
                  String moneyOrBlank(num v) => hasSale ? _fmtMoney(v) : '';
                  final dateText = DateFormat('dd MMM, yyyy').format(r.day); // full date

                  return DataRow(
                    color: (isToday && !hasSale)
                        ? WidgetStatePropertyAll(Colors.red.withValues(alpha: 0.06))
                        : null,
                    cells: [
                      DataCell(Text(dateText, style: style)),
                      DataCell(Text(r.shop, style: style, overflow: TextOverflow.ellipsis)),
                      DataCell(Text(moneyOrBlank(r.total), style: style)),
                      DataCell(Text(moneyOrBlank(r.cash), style: style)),
                      DataCell(Text(moneyOrBlank(r.card), style: style)),
                      DataCell(Text(moneyOrBlank(r.other), style: style)),
                      DataCell(Text(hasSale ? (r.employee ?? '') : '', style: style, overflow: TextOverflow.ellipsis)),
                      DataCell(
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          onSelected: (v) async {
                            // Actions: view / edit / delete / compare
                            if (v == 'view') {
                              final endExcl = r.day.add(const Duration(days: 1));
                              await _openShopSalesDetail(r.shop, r.day, endExcl);
                            }
                            if ((v == 'edit' || v == 'delete' || v == 'compare') && !canEditDelete) return;

                            if (v == 'edit') {
                              await _editLatestSaleForShop(r.shop, r.day, r.day.add(const Duration(days: 1)));
                            }
                            if (v == 'delete') {
                              await _deleteLatestSaleForShop(r.shop, r.day, r.day.add(const Duration(days: 1)));
                            }
                            if (v == 'compare') {
                              await _compareWithTransactions(r.shop, r.day, r.day.add(const Duration(days: 1)));
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(value: 'view',    child: Text('View Sale')),
                            if (canEditDelete) const PopupMenuItem(value: 'edit',    child: Text('Edit Sale')),
                            if (canEditDelete) const PopupMenuItem(value: 'delete',  child: Text('Delete Sale')),
                            if (canEditDelete) const PopupMenuItem(value: 'compare', child: Text('Compare with Transaction')),
                          ],
                          child: const Icon(Icons.more_horiz, size: 18),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --------------------- PER-SHOP DETAIL (unchanged core) ---------------------
  Future<void> _openShopSalesDetail(String shop, DateTime from, DateTime to) async {
    final app = context.read<AppDataProvider>();
    final primary = app.buildSalesQuery(from: from, to: to, shop: shop);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final height = MediaQuery.of(ctx).size.height * 0.85;
        return SizedBox(
          height: height,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: primary.snapshots(),
            builder: (ctx, snap) {
              if (snap.hasError) {
                final err = snap.error;
                if (err is FirebaseException && err.code == 'failed-precondition') {
                  return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    future: app.buildSalesQueryLoose(shop: shop).get(),
                    builder: (ctx, fs) {
                      if (fs.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (fs.hasError) {
                        return Center(child: Text('Error: ${fs.error}'));
                      }
                      final rows = (fs.data?.docs ?? const [])
                          .map((d) => app.mapSaleDoc(d))
                          .where((m) {
                            final dt = m['createdAt'] as DateTime;
                            return !dt.isBefore(from) && dt.isBefore(to);
                          })
                          .toList()
                        ..sort((a, b) => (b['createdAt'] as DateTime)
                            .compareTo(a['createdAt'] as DateTime));
                      return _buildSaleListForShop(shop, rows);
                    },
                  );
                }
                return Center(child: Text('Error: $err'));
              }

              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final rows = snap.data!.docs
                  .map((d) => app.mapSaleDoc(d))
                  .toList()
                ..sort((a, b) => (b['createdAt'] as DateTime)
                    .compareTo(a['createdAt'] as DateTime));

              return _buildSaleListForShop(shop, rows);
            },
          ),
        );
      },
    );
  }

  Widget _buildSaleListForShop(String shop, List<Map<String, dynamic>> rows) {
    final app = context.read<AppDataProvider>();
    final canEditDelete = (app.isAdmin == true) || (app.isManager == true);

    return Scaffold(
      appBar: AppBar(title: Text('Sales • $shop')),
      body: rows.isEmpty
          ? const Center(child: Text('No sales found for this period'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final s = rows[i];
                final when =
                    DateFormat('dd MMM, yyyy – hh:mm a').format(s['createdAt']);
                final totNum = (s['total'] as num?)?.toDouble() ?? 0.0;
                final total = totNum.toStringAsFixed(2);
                final emp = (s['employee'] ?? '').toString();

                return Card(
                  child: ListTile(
                    title: Text('\$ $total',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('By: $emp  •  $when'),
                    onTap: canEditDelete ? () => _editSale(s) : null,
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') _editSale(s);
                        if (v == 'delete') _confirmDelete(s['id'].toString());
                      },
                      itemBuilder: (ctx) => [
                        if (canEditDelete) const PopupMenuItem(value: 'edit', child: Text('Edit Sale')),
                        if (canEditDelete) const PopupMenuItem(value: 'delete', child: Text('Delete Sale')),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<Map<String, dynamic>?> _fetchLatestSaleForShop(
    String shop, DateTime from, DateTime to,
  ) async {
    final app = context.read<AppDataProvider>();
    try {
      final snap = await app
          .buildSalesQuery(from: from, to: to, shop: shop)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return app.mapSaleDoc(snap.docs.first);
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        final fs = await app.buildSalesQueryLoose(shop: shop).get();
        final items = fs.docs
            .map((d) => app.mapSaleDoc(d))
            .where((m) {
              final dt = m['createdAt'] as DateTime;
              return !dt.isBefore(from) && dt.isBefore(to);
            })
            .toList()
          ..sort((a, b) =>
              (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime));
        return items.isEmpty ? null : items.first;
      }
      rethrow;
    }
  }

  Future<void> _editLatestSaleForShop(String shop, DateTime from, DateTime to) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final s = await _fetchLatestSaleForShop(shop, from, to);
    if (s == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No sale to edit for this day')),
      );
      return;
    }
    if (!mounted) return;
    await navigator.push(
      MaterialPageRoute(builder: (_) => AddSaleScreen(existingSale: s)),
    );
  }

  Future<void> _deleteLatestSaleForShop(String shop, DateTime from, DateTime to) async {
    final app = context.read<AppDataProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final s = await _fetchLatestSaleForShop(shop, from, to);
    if (s == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No sale to delete for this day')),
      );
      return;
    }

    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete sale?'),
        content: Text('Shop: $shop\nAmount: \$ ${((s['total'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );

    if (ok == true) {
      await app.deleteSale(s['id'].toString());
      messenger.showSnackBar(const SnackBar(content: Text('Sale deleted')));
    }
  }

  Future<void> _editSale(Map<String, dynamic> sale) async {
    final navigator = Navigator.of(context);
    await navigator.push(
      MaterialPageRoute(builder: (_) => AddSaleScreen(existingSale: sale)),
    );
  }

  Future<void> _confirmDelete(String id) async {
    final app = context.read<AppDataProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete sale?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await app.deleteSale(id);
      messenger.showSnackBar(
        const SnackBar(content: Text('Sale deleted')),
      );
    }
  }

  // --------------------- COMPARE ---------------------
  Future<void> _compareWithTransactions(String shop, DateTime from, DateTime to) async {
    final app = context.read<AppDataProvider>();
    final start = DateTime(from.year, from.month, from.day);
    final endExcl = DateTime(to.year, to.month, to.day); // exclusive already
    final isSingleDay = endExcl.difference(start).inDays == 1;

    double txCash = 0, txCard = 0, txOther = 0, txTotal = 0;

    Future<void> addDayTotals(DateTime day) async {
      final t = await app.computeDailyTransactionTotals(shop, day);
      txCash += (t['cash'] ?? 0).toDouble();
      txCard += (t['card'] ?? 0).toDouble();
      txOther += (t['other'] ?? 0).toDouble();
      txTotal += (t['total'] ?? 0).toDouble();
    }

    if (isSingleDay) {
      await addDayTotals(start);
    } else {
      for (int i = 0; i < endExcl.difference(start).inDays; i++) {
        await addDayTotals(start.add(Duration(days: i)));
      }
    }

    final salesSnap = await app
        .buildSalesQuery(from: start, to: endExcl, shop: shop)
        .get();

    double empTotal = 0;
    for (final d in salesSnap.docs) {
      final m = app.mapSaleDoc(d);
      empTotal += (m['total'] as num?)?.toDouble() ?? 0.0;
    }

    final diff = txTotal - empTotal;
    final titlePeriod = isSingleDay
        ? DateFormat('dd MMM, yyyy').format(start)
        : '${DateFormat('dd MMM, yyyy').format(start)} – ${DateFormat('dd MMM, yyyy').format(endExcl.subtract(const Duration(days: 1)))}';

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Compare: $shop ($titlePeriod)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kv('Transactions Total', '\$ ${txTotal.toStringAsFixed(2)}'),
            _kv('Employee Daily Sale', '\$ ${empTotal.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            const Divider(),
            _kv('Difference', '\$ ${diff.abs().toStringAsFixed(2)}'
                '${diff == 0 ? '' : (diff > 0 ? '  (Tx > Sale)' : '  (Sale > Tx)')}'),
            const SizedBox(height: 8),
            const Text('Breakdown (Transactions):'),
            const SizedBox(height: 4),
            _kv('• Cash',  '\$ ${txCash.toStringAsFixed(2)}'),
            _kv('• Card',  '\$ ${txCard.toStringAsFixed(2)}'),
            _kv('• Other', '\$ ${txOther.toStringAsFixed(2)}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          if (isSingleDay && empTotal == 0 && txTotal > 0)
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final err = await app.postDailySaleFromTransactions(
                  shopName: shop,
                  day: start,
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(err ?? 'Daily Sale created from transactions')),
                );
              },
              child: const Text('Post as Daily Sale'),
            ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(k)),
          Text(v),
        ]),
      );

  // --------------------- HELPERS ---------------------
  // Rolling windows (aaj inclusive): weekly=today-6..today, monthly=today-30..today, yearly=today-365..today
  (DateTime, DateTime) _computeRange() {
    final now = DateTime.now();
    final t = DateTime(now.year, now.month, now.day);

    if (_period == 'Date Range' && _range != null) {
      final start = DateTime(_range!.start.year, _range!.start.month, _range!.start.day);
      var end = DateTime(_range!.end.year, _range!.end.month, _range!.end.day);
      if (end.isAfter(t)) end = t;
      return (start, end.add(const Duration(days: 1)));
    }

    if (_period == 'Weekly') {
      final s = t.subtract(const Duration(days: 6));
      return (s, t.add(const Duration(days: 1)));
    }

    if (_period == 'Monthly') {
      final s = t.subtract(const Duration(days: 30));
      return (s, t.add(const Duration(days: 1)));
    }

    if (_period == 'Yearly') {
      final s = t.subtract(const Duration(days: 365));
      return (s, t.add(const Duration(days: 1)));
    }

    if (_period == 'Specific Date') {
      final d = DateTime(_anchorDate.year, _anchorDate.month, _anchorDate.day);
      final capped = d.isAfter(t) ? t : d;
      return (capped, capped.add(const Duration(days: 1)));
    }

    final d = DateTime(_anchorDate.year, _anchorDate.month, _anchorDate.day);
    final capped = d.isAfter(t) ? t : d;
    return (capped, capped.add(const Duration(days: 1)));
  }

  String _labelForRange(DateTime from, DateTime toExcl) {
    final end = toExcl.subtract(const Duration(days: 1));
    if (_period == 'Daily' || _period == 'Specific Date') {
      return DateFormat('dd MMM, yyyy').format(from);
    }
    return '${DateFormat('dd MMM, yyyy').format(from)} – ${DateFormat('dd MMM, yyyy').format(end)}';
  }

  String _fmtMoney(dynamic v) {
    final d = v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0.0;
    return '\$ ${d.toStringAsFixed(2)}';
  }

  // --------------------- EXPORTS (per-day rows) ---------------------
  Future<void> _exportCsv() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_exportRows.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Nothing to export')),
      );
      return;
    }

    final b = StringBuffer();
    // Date first in CSV as well (to match UI flow)
    b.writeln('Date,Shop,Total,Cash,Card,Other,Employee');

    for (final r in _exportRows) {
      final dateCsv = DateFormat('dd MMM, yyyy').format(r.day);
      b.writeln([
        _csvEsc(dateCsv),
        _csvEsc(r.shop),
        r.total.toStringAsFixed(2),
        r.cash.toStringAsFixed(2),
        r.card.toStringAsFixed(2),
        r.other.toStringAsFixed(2),
        _csvEsc(r.employee ?? ''),
      ].join(','));
    }

    final dir = await getTemporaryDirectory();
    final name =
        'sales_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
    final file = File('${dir.path}/$name');
    await file.writeAsString(b.toString(), flush: true);

    await Share.shareXFiles([XFile(file.path)], text: 'Sales CSV');
  }

  String _csvEsc(String s) {
    final needs = s.contains(',') || s.contains('\n') || s.contains('"');
    if (!needs) return s;
    return '"${s.replaceAll('"', '""')}"';
  }

  Future<void> _exportPdf() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_exportRows.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Nothing to export')),
      );
      return;
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (ctx) => [
          pw.Text('Sales Report (Per-Day)',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          if (_lastFrom != null && _lastTo != null)
            pw.Text('Range: ${DateFormat('dd MMM, yyyy').format(_lastFrom!)} – '
                '${DateFormat('dd MMM, yyyy').format(_lastTo!.subtract(const Duration(days: 1)))}'),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: const ['Date','Shop','Total','Cash','Card','Other','Employee'],
            data: _exportRows.map((r) {
              final dateCsv = DateFormat('dd MMM, yyyy').format(r.day);
              return [
                dateCsv,
                r.shop,
                r.total.toStringAsFixed(2),
                r.cash.toStringAsFixed(2),
                r.card.toStringAsFixed(2),
                r.other.toStringAsFixed(2),
                r.employee ?? '',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
            cellStyle: pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    final name =
        'sales_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: name);
  }
}

// ===============================================================
// Bottom sheet: Daily Sale from Transactions (Admin/Manager only)
// ===============================================================
class _DailySaleFromTransactionsSheet extends StatefulWidget {
  const _DailySaleFromTransactionsSheet();

  @override
  State<_DailySaleFromTransactionsSheet> createState() =>
      _DailySaleFromTransactionsSheetState();
}

class _DailySaleFromTransactionsSheetState
    extends State<_DailySaleFromTransactionsSheet> {
  String? _shop;
  DateTime _day = DateTime.now();
  Map<String, double>? _totals;
  bool _loading = false;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked != null) setState(() => _day = picked);
  }

  Future<void> _compute() async {
    final app = context.read<AppDataProvider>();
    if ((_shop ?? '').isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select a shop')));
      return;
    }
    setState(() => _loading = true);
    final res = await app.computeDailyTransactionTotals(_shop!, _day);
    if (!mounted) return;
    setState(() {
      _totals = res;
      _loading = false;
    });
  }

  Future<void> _post() async {
    final app = context.read<AppDataProvider>();
    if ((_shop ?? '').isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select a shop')));
      return;
    }
    setState(() => _loading = true);
    final res = await app.postDailySaleFromTransactions(
      shopName: _shop!,
      day: _day,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(res ?? 'Daily sale posted')),
    );
  }

  @override
  Widget build(BuildContext context) {
    const currency = '\$';
    final app = context.watch<AppDataProvider>();
    final shops = app.shops
        .where((s) => (s['isDeleted'] ?? false) != true)
        .map((s) => (s['name'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList()
      ..sort();

    _shop ??= (shops.isNotEmpty ? shops.first : null);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Daily Sale from Transactions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _shop,
              items: shops
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _shop = v),
              decoration: const InputDecoration(labelText: 'Shop'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(DateFormat('MMM d, yyyy').format(_day)),
                ),
                TextButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('Pick date'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _compute,
                    icon: const Icon(Icons.calculate_outlined),
                    label: Text(_loading ? 'Computing…' : 'Compute'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (_totals != null && !_loading) ? _post : null,
                    icon: const Icon(Icons.publish_outlined),
                    label: const Text('Post Daily Sale'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_totals != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _row('Cash', _totals!['cash'] ?? 0, currency),
                      _row('Card', _totals!['card'] ?? 0, currency),
                      _row('Other', _totals!['other'] ?? 0, currency),
                      const Divider(),
                      _row('Total', _totals!['total'] ?? 0, currency, bold: true),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, double value, String currency, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label),
          const Spacer(),
          Text(
            '$currency ${value.toStringAsFixed(2)}',
            style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w400),
          ),
        ],
      ),
    );
  }
}
