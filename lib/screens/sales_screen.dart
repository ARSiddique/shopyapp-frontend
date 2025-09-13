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

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  // ---- Filters ----
  String _period = 'Daily';
  String _selectedShop = 'All';
  DateTime _anchorDate = DateTime.now();
  DateTimeRange? _range;

  // Daily/SpecificDate + today cutoff
  final int _cutoffHour = 21;

  // Export cache
  List<_ShopRow> _lastRows = [];
  DateTime? _lastFrom;
  DateTime? _lastTo;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();

    final shops = app.shops
        .where((s) => (s['isDeleted'] ?? false) != true)
        .map((s) => (s['name'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList()
      ..sort();

    final allShopOptions = ['All', ...shops];

    if (_selectedShop != 'All' && !shops.contains(_selectedShop)) {
      _selectedShop = 'All';
    }

    final visibleShops = (_selectedShop != 'All' && shops.contains(_selectedShop))
        ? <String>[_selectedShop]
        : shops;

    final (from, to) = _computeRange();
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

          // Add Sale: Admin/Manager -> ShopSelection (Actions hub), Employee -> direct form
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

          // Admin/Manager only: compute+post from transactions
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
          const SizedBox(height: 8),
          _filtersRow(allShopOptions, periodLabel),
          const SizedBox(height: 8),
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

  // --------------------- FILTERS ROW ---------------------

  Widget _filtersRow(List<String> shopOptions, String periodLabel) {
    final theme = Theme.of(context);
    final isRange = _period == 'Date Range';
    final isSpecific = _period == 'Specific Date';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Shop
            SizedBox(
              width: 170,
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
            const SizedBox(width: 12),

            // Period
            SizedBox(
              width: 180,
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
            const SizedBox(width: 12),

            // Picker button
            if (isRange)
              _rangePickerButton(theme)
            else
              _datePickerButton(theme, periodLabel, isSpecific),

            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _datePickerButton(ThemeData theme, String periodLabel, bool isSpecific) {
    final btnLabel = isSpecific ? 'Pick date' : 'Anchor date';
    final sub = periodLabel;

    return OutlinedButton.icon(
      icon: const Icon(Icons.event),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(btnLabel),
          const SizedBox(width: 6),
          Text(
            sub,
            style: TextStyle(
              fontSize: 12,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
      onPressed: _pickAnchorDate,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _rangePickerButton(ThemeData theme) {
    final label = (_range == null)
        ? 'Pick range'
        : '${DateFormat('dd MMM, yyyy').format(_range!.start)}  –  ${DateFormat('dd MMM, yyyy').format(_range!.end)}';

    return OutlinedButton.icon(
      icon: const Icon(Icons.date_range),
      label: Text(label),
      onPressed: _pickRange,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Future<void> _pickAnchorDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchorDate,
      firstDate: DateTime(2022, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _anchorDate = picked);
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _range ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 6)),
            end: DateTime.now(),
          ),
      firstDate: DateTime(2022, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
                final rows = _aggregate(
                  docs.map((d) => app.mapSaleDoc(d)).where((m) {
                    final dt = m['createdAt'] as DateTime;
                    return !dt.isBefore(from) && dt.isBefore(to);
                  }).toList(),
                  allShops,
                );
                return _buildTable(rows, from, to);
              },
            );
          }
          return Center(child: Text('Error: $err'));
        }

        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snap.data!.docs;
        final rows = _aggregate(
          docs.map((d) => app.mapSaleDoc(d)).toList(),
          allShops,
        );
        return _buildTable(rows, from, to);
      },
    );
  }

  // Make sure all shops appear (even with blanks) + aggregate totals
  List<_ShopRow> _aggregate(List<Map<String, dynamic>> sales, List<String> allShops) {
    final map = <String, _ShopRow>{};

    for (final s in allShops) {
      map[s] = _ShopRow(shop: s);
    }

    for (final m in sales) {
      final shop = (m['shop'] ?? '').toString();
      final cash = (m['cash'] as num?)?.toDouble() ?? 0.0;
      final card = (m['card'] as num?)?.toDouble() ?? 0.0;
      final other = (m['other'] as num?)?.toDouble() ?? 0.0;
      final total = (m['total'] as num?)?.toDouble() ?? (cash + card + other);
      final emp = (m['employee'] ?? m['addedBy'] ?? '').toString();
      final dt = (m['createdAt'] as DateTime?) ?? DateTime.now();

      final row = map[shop] ?? _ShopRow(shop: shop);
      row.cash += cash;
      row.card += card;
      row.other += other;
      row.total += total;
      if (row.lastSaleAt == null || dt.isAfter(row.lastSaleAt!)) {
        row.lastSaleAt = dt;
        row.employee = emp;
      }
      map[shop] = row;
    }

    final rows = map.values.toList()
      ..sort((a, b) {
        final ad = a.lastSaleAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.lastSaleAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });
    return rows;
  }

  Widget _buildTable(List<_ShopRow> rows, DateTime from, DateTime to) {
    _lastRows = rows;
    _lastFrom = from;
    _lastTo = to;

    final now = DateTime.now();
    final isDailyOrSpecific = _period == 'Daily' || _period == 'Specific Date';
    final isToday = isDailyOrSpecific &&
        from.year == now.year &&
        from.month == now.month &&
        from.day == now.day;
    final afterCutoff = now.hour >= _cutoffHour;

    final periodText = _labelForRange(from, to);
    final headerStyle = TextStyle(
      fontWeight: FontWeight.w700,
      color: Theme.of(context).colorScheme.onSurface,
    );

    final app = context.read<AppDataProvider>();
    final canEditDelete = (app.isAdmin == true) || (app.isManager == true);

    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 920),
          child: SingleChildScrollView(
            child: DataTableTheme(
              data: DataTableThemeData(headingTextStyle: headerStyle),
              child: DataTable(
                headingRowHeight: 40,
                columns: const [
                  DataColumn(label: Text('Shop')),
                  DataColumn(label: Text('Period')),
                  DataColumn(label: Text('Total')),
                  DataColumn(label: Text('Employee')),
                  DataColumn(label: Text('Cash')),
                  DataColumn(label: Text('Card')),
                  DataColumn(label: Text('Other')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: rows.map((r) {
                  final hasSale =
                      (r.total > 0) || (r.cash > 0) || (r.card > 0) || (r.other > 0);

                  String moneyOrBlank(num v) => hasSale ? _fmtMoney(v) : '';
                  final employeeText =
                      hasSale && (r.employee?.isNotEmpty ?? false) ? r.employee! : '';

                  final danger = isToday && afterCutoff && !hasSale;
                  final textStyle = danger
                      ? TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600)
                      : const TextStyle();

                  return DataRow(
                    color: danger
                        ? WidgetStatePropertyAll(
                            Colors.red.withValues(alpha: 0.08),
                          )
                        : null,
                    cells: [
                      DataCell(Text(r.shop, style: textStyle)),
                      DataCell(Text(periodText, style: textStyle)),
                      DataCell(Text(moneyOrBlank(r.total), style: textStyle)),
                      DataCell(Text(employeeText, style: textStyle)),
                      DataCell(Text(moneyOrBlank(r.cash), style: textStyle)),
                      DataCell(Text(moneyOrBlank(r.card), style: textStyle)),
                      DataCell(Text(moneyOrBlank(r.other), style: textStyle)),

                      DataCell(
                        canEditDelete
                            ? PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'view') _openShopSalesDetail(r.shop, from, to);
                                  if (v == 'edit_latest') _editLatestSaleForShop(r.shop, from, to);
                                  if (v == 'delete_latest') _deleteLatestSaleForShop(r.shop, from, to);
                                  if (v == 'compare_period') _compareWithTransactions(r.shop, from, to);
                                },
                                itemBuilder: (ctx) => const [
                                  PopupMenuItem(value: 'view', child: Text('View sales')),
                                  PopupMenuItem(value: 'edit_latest', child: Text('Edit latest')),
                                  PopupMenuItem(value: 'delete_latest', child: Text('Delete latest')),
                                  PopupMenuItem(
                                    value: 'compare_period',
    child: Text('Compare with Transactions (Period)'),
                                  ),
                                ],
                                child: const Icon(Icons.more_horiz),
                              )
                            : IconButton(
                                tooltip: 'View sales',
                                icon: const Icon(Icons.visibility_outlined),
                                onPressed: () => _openShopSalesDetail(r.shop, from, to),
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

  // --------------------- PER-SHOP DETAIL ---------------------

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
                final total = totNum.toStringAsFixed(0);
                final emp = (s['employee'] ?? '').toString();

                return Card(
                  child: ListTile(
                    title: Text('Rs $total',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('By: $emp  •  $when'),
                    onTap: canEditDelete ? () => _editSale(s) : null,
                    trailing: canEditDelete
                        ? PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'edit') _editSale(s);
                              if (v == 'delete') _confirmDelete(s['id'].toString());
                            },
                            itemBuilder: (ctx) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          )
                        : null,
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

  // 🔹 NEW: fetch only manual (employee/admin) sale — exclude transactions_close_day
  Future<Map<String, dynamic>?> _fetchEmployeeManualSaleForShop(
    String shop, DateTime from, DateTime to,
  ) async {
    final app = context.read<AppDataProvider>();
    try {
      final snap = await app
          .buildSalesQuery(from: from, to: to, shop: shop)
          .get();

      Map<String, dynamic> mapDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
        final m = d.data();
        DateTime created;
        final raw = m['createdAt'];
        if (raw is Timestamp) {
          created = raw.toDate();
        } else if (raw is DateTime) {
          created = raw;
        } else if (raw is String) {
          created = DateTime.tryParse(raw) ?? DateTime.now();
        } else {
          created = DateTime.now();
        }
        double toD(v) =>
            v is num ? v.toDouble() : double.tryParse('${v ?? ""}') ?? 0.0;

        return {
          'id': d.id,
          'shop': (m['shop'] ?? '').toString(),
          'employee': (m['employee'] ?? m['addedBy'] ?? '').toString(),
          'cash': toD(m['cash']),
          'card': toD(m['card']),
          'other': toD(m['other']),
          'total': toD(m['total']),
          'createdAt': created,
          'source': (m['source'] ?? '').toString(),
        };
      }

      final items = snap.docs
          .map(mapDoc)
          .where((m) {
            final src = (m['source'] ?? '').toString();
            return src != 'transactions_close_day';
          })
          .toList()
        ..sort((a, b) =>
            (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime));

      return items.isEmpty ? null : items.first;
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        final fs = await app.buildSalesQueryLoose(shop: shop).get();
        final items = fs.docs
            .map((d) {
              final m = d.data();
              final created = (m['createdAt'] is Timestamp)
                  ? (m['createdAt'] as Timestamp).toDate()
                  : DateTime.now();
              double toD(v) =>
                  v is num ? v.toDouble() : double.tryParse('${v ?? ""}') ?? 0.0;
              return {
                'id': d.id,
                'shop': (m['shop'] ?? '').toString(),
                'employee': (m['employee'] ?? m['addedBy'] ?? '').toString(),
                'cash': toD(m['cash']),
                'card': toD(m['card']),
                'other': toD(m['other']),
                'total': toD(m['total']),
                'createdAt': created,
                'source': (m['source'] ?? '').toString(),
              };
            })
            .where((m) {
              final dt = m['createdAt'] as DateTime;
              final src = (m['source'] ?? '').toString();
              return !dt.isBefore(from) && dt.isBefore(to) &&
                     src != 'transactions_close_day';
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
        const SnackBar(content: Text('No sale to edit for this period')),
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
        const SnackBar(content: Text('No sale to delete for this period')),
      );
      return;
    }

    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete latest sale?'),
        content: Text('Shop: $shop\nAmount: Rs ${((s['total'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}'),
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

  // --------------------- COMPARE (TODAY) ---------------------

  Future<void> _compareWithTransactions(String shop, DateTime from, DateTime to) async {
  final app = context.read<AppDataProvider>();
  // normalize to midnight boundaries
  final start = DateTime(from.year, from.month, from.day);
  final endExcl = DateTime(to.year, to.month, to.day); // exclusive already
  final isSingleDay = endExcl.difference(start).inDays == 1;

  // ---------- Transactions total (day-by-day aggregate if needed) ----------
  double txCash = 0, txCard = 0, txOther = 0, txTotal = 0;

  Future<void> addDayTotals(DateTime day) async {
    final t = await app.computeDailyTransactionTotals(shop, day); // {cash, card, other, total}
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

  // ---------- Sales total (employee/admin posted) within the same period ----------
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
          _kv('Transactions Total', 'Rs ${txTotal.toStringAsFixed(0)}'),
          _kv('Employee Daily Sale', 'Rs ${empTotal.toStringAsFixed(0)}'),
          const SizedBox(height: 8),
          const Divider(),
          _kv('Difference', 'Rs ${diff.abs().toStringAsFixed(0)}'
              '${diff == 0 ? '' : (diff > 0 ? '  (Tx > Sale)' : '  (Sale > Tx)')}'),
          const SizedBox(height: 8),
          const Text('Breakdown (Transactions):'),
          const SizedBox(height: 4),
          _kv('• Cash',  'Rs ${txCash.toStringAsFixed(0)}'),
          _kv('• Card',  'Rs ${txCard.toStringAsFixed(0)}'),
          _kv('• Other', 'Rs ${txOther.toStringAsFixed(0)}'),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        if (isSingleDay && empTotal == 0 && txTotal > 0) // helpful shortcut
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

  (DateTime, DateTime) _computeRange() {
    if (_period == 'Date Range' && _range != null) {
      final start = DateTime(_range!.start.year, _range!.start.month, _range!.start.day);
      final end = DateTime(_range!.end.year, _range!.end.month, _range!.end.day)
          .add(const Duration(days: 1));
      return (start, end);
    }

    if (_period == 'Weekly') {
      final start = _anchorDate.subtract(Duration(days: _anchorDate.weekday - 1));
      final s = DateTime(start.year, start.month, start.day);
      return (s, s.add(const Duration(days: 7)));
    }

    if (_period == 'Monthly') {
      final s = DateTime(_anchorDate.year, _anchorDate.month, 1);
      final e = DateTime(_anchorDate.year, _anchorDate.month + 1, 1);
      return (s, e);
    }

    if (_period == 'Yearly') {
      final s = DateTime(_anchorDate.year, 1, 1);
      final e = DateTime(_anchorDate.year + 1, 1, 1);
      return (s, e);
    }

    final s = DateTime(_anchorDate.year, _anchorDate.month, _anchorDate.day);
    return (s, s.add(const Duration(days: 1)));
  }

  String _labelForRange(DateTime from, DateTime to) {
    final end = to.subtract(const Duration(days: 1));
    if (_period == 'Daily' || _period == 'Specific Date') {
      return DateFormat('dd MMM, yyyy').format(from);
    }
    if (_period == 'Weekly' || _period == 'Date Range') {
      return '${DateFormat('dd MMM, yyyy').format(from)} – ${DateFormat('dd MMM, yyyy').format(end)}';
    }
    if (_period == 'Monthly') return DateFormat('MMM yyyy').format(from);
    if (_period == 'Yearly') return DateFormat('yyyy').format(from);
    return '${DateFormat('dd MMM').format(from)} – ${DateFormat('dd MMM').format(end)}';
  }

  String _fmtMoney(dynamic v) {
    final d = v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0.0;
    return 'Rs ${d.toStringAsFixed(0)}';
  }

  // --------------------- EXPORTS ---------------------

  Future<void> _exportCsv() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_lastRows.isEmpty || _lastFrom == null || _lastTo == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Nothing to export')),
      );
      return;
    }

    final b = StringBuffer();
    b.writeln('Shop,Period,Total,Employee,Cash,Card,Other');

    final periodText = _labelForRange(_lastFrom!, _lastTo!);
    for (final r in _lastRows) {
      b.writeln([
        _csvEsc(r.shop),
        _csvEsc(periodText),
        r.total.toStringAsFixed(0),
        _csvEsc(r.employee ?? ''),
        r.cash.toStringAsFixed(0),
        r.card.toStringAsFixed(0),
        r.other.toStringAsFixed(0),
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
    if (_lastRows.isEmpty || _lastFrom == null || _lastTo == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Nothing to export')),
      );
      return;
    }

    final pdf = pw.Document();
    final periodText = _labelForRange(_lastFrom!, _lastTo!);

    pdf.addPage(
      pw.MultiPage(
        build: (ctx) => [
          pw.Text('Sales Report',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Period: $periodText'),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: const ['Shop', 'Period', 'Total', 'Employee', 'Cash', 'Card', 'Other'],
            data: _lastRows.map((r) {
              return [
                r.shop,
                periodText,
                r.total.toStringAsFixed(0),
                r.employee ?? '',
                r.cash.toStringAsFixed(0),
                r.card.toStringAsFixed(0),
                r.other.toStringAsFixed(0),
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

// Row model
class _ShopRow {
  _ShopRow({required this.shop});

  final String shop;
  double cash = 0.0;
  double card = 0.0;
  double other = 0.0;
  double total = 0.0;
  String? employee;
  DateTime? lastSaleAt;
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
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
    const currency = 'Rs';
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
