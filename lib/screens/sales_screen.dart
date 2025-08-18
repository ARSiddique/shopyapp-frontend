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

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  // ---- Filters ----
  String _period = 'Daily'; // Daily | Weekly | Monthly | Yearly | Specific Date | Date Range
  String _selectedShop = 'All';
  DateTime _anchorDate = DateTime.now(); // for non-range periods + specific date
  DateTimeRange? _range; // for "Date Range"

  // Daily/SpecificDate + today cutoff (no sale → red row)
  final int _cutoffHour = 15; // 3 PM

  // Export cache
  List<_ShopRow> _lastRows = [];
  DateTime? _lastFrom;
  DateTime? _lastTo;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();

    // Active shops
    final shops = app.shops
        .where((s) => (s['isDeleted'] ?? false) != true)
        .map((s) => (s['name'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList()
      ..sort();

    // Dropdown options
    final allShopOptions = ['All', ...shops];

    // If selected shop vanished, fallback to All
    if (_selectedShop != 'All' && !shops.contains(_selectedShop)) {
      _selectedShop = 'All';
    }

    // Visible list for table (so only selected shop appears)
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
          IconButton(
            tooltip: 'Add Sale',
            onPressed: () {
              final navigator = Navigator.of(context);
              navigator.push(
                MaterialPageRoute(builder: (_) => const AddSaleScreen()),
              );
            },
            icon: const Icon(Icons.add),
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
              allShops: visibleShops, // <= only selected shop if filtered
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

                  // Auto-open the relevant picker after dropdown closes
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

            // Explicit pickers (buttons) still available
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
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8), // ✅
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

  // --------------------- DATA TABLE (stream + fallback) ---------------------

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
            // fallback: loose + local filter
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

    // pre-seed so every shop shows even with no sale
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
        row.employee = emp; // last seller
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
    // cache for export
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
                  // has any sale?
                  final hasSale =
                      (r.total > 0) || (r.cash > 0) || (r.card > 0) || (r.other > 0);

                  // blanks when no sale yet
                  String moneyOrBlank(num v) => hasSale ? _fmtMoney(v) : '';
                  final employeeText =
                      hasSale && (r.employee?.isNotEmpty ?? false) ? r.employee! : '';

                  final danger = isToday && afterCutoff && !hasSale;
                  final textStyle = danger
                      ? TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600)
                      : const TextStyle();

                  return DataRow(
                    color: danger
                        ? WidgetStatePropertyAll( // ✅
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

                      // Actions: View / Edit latest / Delete latest
                      DataCell(
                        PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'view') _openShopSalesDetail(r.shop, from, to);
                            if (v == 'edit_latest') _editLatestSaleForShop(r.shop, from, to);
                            if (v == 'delete_latest') _deleteLatestSaleForShop(r.shop, from, to);
                          },
                          itemBuilder: (ctx) => const [
                            PopupMenuItem(value: 'view', child: Text('View sales')),
                            PopupMenuItem(value: 'edit_latest', child: Text('Edit latest')),
                            PopupMenuItem(value: 'delete_latest', child: Text('Delete latest')),
                          ],
                          child: const Icon(Icons.more_horiz),
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

  // --------------------- PER-SHOP DETAIL (VIEW / EDIT / DELETE) ---------------------

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
                final total = (s['total'] as double).toStringAsFixed(0);
                final emp = (s['employee'] ?? '').toString();

                return Card(
                  child: ListTile(
                    title: Text('Rs. $total',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('By: $emp  •  $when'),
                    onTap: () => _editSale(s),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') _editSale(s);
                        if (v == 'delete') _confirmDelete(s['id'].toString());
                      },
                      itemBuilder: (ctx) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
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
  final navigator = Navigator.of(context); // pre-capture
  final messenger = ScaffoldMessenger.of(context); // pre-capture

  final s = await _fetchLatestSaleForShop(shop, from, to);
  if (s == null) {
    messenger.showSnackBar(
      const SnackBar(content: Text('No sale to edit for this period')),
    );
    return;
  }
  if (!mounted) return; // ✅ guard after async gap
  await navigator.push(
    MaterialPageRoute(builder: (_) => AddSaleScreen(existingSale: s)),
  );
}

Future<void> _deleteLatestSaleForShop(String shop, DateTime from, DateTime to) async {
  final app = context.read<AppDataProvider>();           // pre-capture
  final messenger = ScaffoldMessenger.of(context);       // pre-capture

  final s = await _fetchLatestSaleForShop(shop, from, to);
  if (s == null) {
    messenger.showSnackBar(
      const SnackBar(content: Text('No sale to delete for this period')),
    );
    return;
  }

  if (!mounted) return; // ✅ guard before using context in showDialog
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete latest sale?'),
      content: Text('Shop: $shop\nAmount: Rs. ${(s['total'] as double).toStringAsFixed(0)}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
      ],
    ),
  );

  if (ok == true) {
    await app.deleteSale(s['id'].toString());
    // messenger safe to use (doesn't depend on mounted), but fine as-is:
    messenger.showSnackBar(const SnackBar(content: Text('Sale deleted')));
  }
}

  Future<void> _editSale(Map<String, dynamic> sale) async {
    final navigator = Navigator.of(context); // ✅ pre-capture
    await navigator.push(
      MaterialPageRoute(builder: (_) => AddSaleScreen(existingSale: sale)),
    );
  }

  Future<void> _confirmDelete(String id) async {
    final app = context.read<AppDataProvider>(); // ✅ pre-capture
    final messenger = ScaffoldMessenger.of(context); // ✅ pre-capture

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

  // --------------------- HELPERS ---------------------

  // Returns (from, to) [to exclusive]
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

    // Daily + Specific Date
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
    return 'Rs. ${d.toStringAsFixed(0)}';
  }

  // --------------------- EXPORTS ---------------------

  Future<void> _exportCsv() async {
    final messenger = ScaffoldMessenger.of(context); // ✅ pre-capture
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
    final messenger = ScaffoldMessenger.of(context); // ✅ pre-capture
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
          pw.TableHelper.fromTextArray( // ✅
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

// Row model for aggregation
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
