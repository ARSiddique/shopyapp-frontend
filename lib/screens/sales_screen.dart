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

/// ---------- Aggregate row model ----------
class _AggRow {
  _AggRow({required this.shop});
  final String shop;
  double cash = 0.0;
  double card = 0.0;
  double other = 0.0;
  double total = 0.0;
  String? lastEmployee;
  DateTime? lastSaleAt;
}

enum _ViewMode { detailed, aggregate }

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key, this.initialShopName});

  /// Shop Selection se aane par default filter
  final String? initialShopName;

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  // ---- Filters ----
  String _period = 'Daily';       // DEFAULT: Daily  (was Weekly)
  String _selectedShop = 'All';
  DateTime _anchorDate = DateTime.now();
  DateTimeRange? _range;

  // View type
  _ViewMode _view = _ViewMode.aggregate; // DEFAULT: Aggregate (was Detailed)

  // export cache
  List<_DayRow> _exportRows = [];
  DateTime? _lastFrom;
  DateTime? _lastTo;

  bool _bootstrapped = false; // pick first shop once

  @override
  void initState() {
    super.initState();
    // agar shop selection se naam aaya ho to direct use kar lein
    final name = (widget.initialShopName ?? '').trim();
    if (name.isNotEmpty) _selectedShop = name;
    // ensure anchor = today (no future)
    final now = DateTime.now();
    _anchorDate = DateTime(now.year, now.month, now.day);
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

    // default to first shop once (agar initialShopName empty ho)
    if (!_bootstrapped && shops.isNotEmpty) {
      _bootstrapped = true;
      if (_selectedShop == 'All' && (widget.initialShopName ?? '').isEmpty) {
        _selectedShop = shops.first;
      }
      // (No forced Weekly here; keep Daily as requested)
    }

    final allShopOptions = ['All', ...shops];

    if (_selectedShop != 'All' && !shops.contains(_selectedShop)) {
      _selectedShop = 'All';
    }

    final visibleShops = (_selectedShop != 'All' && shops.contains(_selectedShop))
        ? <String>[_selectedShop]
        : shops;

    final (from, toExcl) = _computeRange(); // [from .. to) exclusive
    final periodLabel = _labelForRange(from, toExcl);

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
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 6),
          _filtersRow(allShopOptions, periodLabel),
          const SizedBox(height: 6),
          Expanded(
            child: (_view == _ViewMode.detailed)
                ? _tableStreamDetailed(
                    from: from,
                    to: toExcl,
                    selectedShop: _selectedShop,
                    allShops: visibleShops,
                  )
                : _tableStreamAggregate(
                    from: from,
                    to: toExcl,
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

  Widget dateControl() =>
      isRange ? _rangePickerBar(theme) : _datePickerBar(theme, periodLabel, isSpecific);

  // Compact, predictable widths (tweak if needed)
  const double _shopW   = 140;
  const double _periodW = 140;
  const double _typeW   = 140;

  final shopField = SizedBox(
    width: _shopW,
    child: DropdownButtonFormField<String>(
      isDense: true,
      value: shopOptions.contains(_selectedShop) ? _selectedShop : 'All',
      items: shopOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
      onChanged: (v) => setState(() => _selectedShop = v ?? 'All'),
      decoration: const InputDecoration(labelText: 'Shop', isDense: true, border: UnderlineInputBorder()),
    ),
  );

  final periodField = SizedBox(
    width: _periodW,
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
      onChanged: (v) async {
        if (v == null) return;
        final now = DateTime.now(), today = DateTime(now.year, now.month, now.day);
        setState(() {
          _period = v;
          if (_period == 'Daily' || _period == 'Weekly') _anchorDate = today;
          if (_period == 'Monthly') _anchorDate = DateTime(today.year, today.month, 1);
          if (_period == 'Yearly')  _anchorDate = DateTime(today.year, 1, 1);
          if (_period != 'Date Range') _range = null;
        });
        if (!mounted) return;
        if (_period == 'Specific Date') await _pickAnchorDate();
        else if (_period == 'Date Range') await _pickRange();
      },
      decoration: const InputDecoration(labelText: 'Period', isDense: true, border: UnderlineInputBorder()),
    ),
  );

  final typeField = SizedBox(
    width: _typeW,
    child: DropdownButtonFormField<_ViewMode>(
      isDense: true,
      value: _view,
      items: const [
        DropdownMenuItem(value: _ViewMode.detailed, child: Text('Detailed View')),
        DropdownMenuItem(value: _ViewMode.aggregate, child: Text('Aggregate View')),
      ],
      onChanged: (v) => setState(() => _view = v ?? _ViewMode.aggregate),
      decoration: const InputDecoration(labelText: 'Type of Sale', isDense: true, border: UnderlineInputBorder()),
    ),
  );

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: LayoutBuilder(
      builder: (ctx, c) {
        // WIDE: ek hi row; date cluster right pe, lekin edge se inset
        if (c.maxWidth >= 520) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              shopField,
              const SizedBox(width: 10),
              periodField,
              const SizedBox(width: 10),
              const Spacer(),          // center space — right cluster ko push karta hai
              typeField,
              const SizedBox(width: 8),
              // Date cluster: fixed max width + right margin (edge se 12px)
              Container(
                margin: const EdgeInsets.only(right: 12),
                constraints: const BoxConstraints(maxWidth: 150),
                child: dateControl(),
              ),
            ],
          );
        }

        // NARROW: wrap; date hamesha Type ke turant baad
        return Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: [
            shopField,
            periodField,
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                typeField,
                const SizedBox(width: 8),
                Container(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: dateControl(),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}

  /// NOTE: “Anchor” text removed — only date/period shown beside calendar icon
 Widget _datePickerBar(ThemeData theme, String periodLabel, bool isSpecific) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _navIconButton(Icons.chevron_left, () => _shiftAnchor(-1)),
      const SizedBox(width: 4),
      // Calendar pill shrinks and ellipsizes text
      Flexible(
        child: OutlinedButton.icon(
          icon: const Icon(Icons.event, size: 16),
          label: Text(
            periodLabel,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(
              fontSize: 12,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8),
            ),
          ),
          onPressed: _pickAnchorDate,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            minimumSize: const Size(100, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
          ),
        ),
      ),
      const SizedBox(width: 4),
      _navIconButton(Icons.chevron_right, () => _shiftAnchor(1)),
    ],
  );
}

  Widget _rangePickerBar(ThemeData theme) {
  final label = (_range == null)
      ? 'Pick range'
      : '${DateFormat('dd MMM, yyyy').format(_range!.start)}  –  ${DateFormat('dd MMM, yyyy').format(_range!.end)}';
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _navIconButton(Icons.chevron_left, () => _shiftRange(-1)),
      const SizedBox(width: 4),
      Flexible(
        child: OutlinedButton.icon(
          icon: const Icon(Icons.date_range, size: 16),
          label: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1),
          onPressed: _pickRange,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            minimumSize: const Size(120, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
          ),
        ),
      ),
      const SizedBox(width: 4),
      _navIconButton(Icons.chevron_right, () => _shiftRange(1)),
    ],
  );
}

Widget _navIconButton(IconData icon, VoidCallback onPressed) {
  return SizedBox(
    width: 32, height: 32,
    child: IconButton(
      padding: EdgeInsets.zero,
      iconSize: 18,
      onPressed: onPressed,
      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
      icon: Icon(icon),
    ),
  );
}
  // --------------------- DATE PICKERS / SHIFTS ---------------------
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
    final initial = _range ??
        DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month, now.day),
        );
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: initial,
      firstDate: DateTime(2022, 1, 1),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked != null) setState(() => _range = picked);
  }

  void _shiftAnchor(int dir) {
    // dir = -1 prev, +1 next
    DateTime d = _anchorDate;
    switch (_period) {
      case 'Daily':
      case 'Specific Date':
        d = d.add(Duration(days: 1 * dir));
        break;
      case 'Weekly':
        d = d.add(Duration(days: 7 * dir));
        break;
      case 'Monthly':
        d = DateTime(d.year, d.month + dir, 1);
        break;
      case 'Yearly':
        d = DateTime(d.year + dir, 1, 1);
        break;
      default:
        return;
    }
    final today = DateTime.now();
    if (!d.isAfter(DateTime(today.year, today.month, today.day))) {
      setState(() => _anchorDate = d);
    }
  }

  void _shiftRange(int dir) {
    if (_range == null) return;
    final len = _range!.end.difference(_range!.start).inDays + 1;
    final start = _range!.start.add(Duration(days: len * dir));
    final end = _range!.end.add(Duration(days: len * dir));
    final t = DateTime.now();
    final cap = DateTime(t.year, t.month, t.day);
    final newEnd = end.isAfter(cap) ? cap : end;
    final delta = end.difference(newEnd).inDays;
    final newStart = start.subtract(Duration(days: delta));
    setState(() => _range = DateTimeRange(start: newStart, end: newEnd));
  }

  // --------------------- DETAILED TABLE (per-day) ---------------------
  Widget _tableStreamDetailed({
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

    final app = context.read<AppDataProvider>();
    final canEditDelete = (app.isAdmin == true) || (app.isManager == true);

    return Scrollbar(
      child: SingleChildScrollView(
        // vertical scroll (FIX)
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          // horizontal scroll
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 820),
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
                  horizontalMargin: 8,
                  columnSpacing: 0,
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
                  rows: rows.map((r) {
                    final hasSale = (r.total > 0) || (r.cash > 0) || (r.card > 0) || (r.other > 0);
                    String moneyOrBlank(num v) => hasSale ? _fmtMoney(v) : '';
                    final dateText = DateFormat('dd MMM, yyyy').format(r.day);

                    return DataRow(
                      cells: [
                        DataCell(Text(dateText)),
                        DataCell(Text(r.shop, overflow: TextOverflow.ellipsis)),
                        DataCell(Text(moneyOrBlank(r.total))),
                        DataCell(Text(moneyOrBlank(r.cash))),
                        DataCell(Text(moneyOrBlank(r.card))),
                        DataCell(Text(moneyOrBlank(r.other))),
                        DataCell(Text(hasSale ? (r.employee ?? '') : '', overflow: TextOverflow.ellipsis)),
                        DataCell(
                          PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            onSelected: (v) async {
                              final endExcl = r.day.add(const Duration(days: 1));
                              if (v == 'view') {
                                await _openShopSalesDetail(r.shop, r.day, endExcl);
                              }
                              if ((v == 'edit' || v == 'delete' || v == 'compare') && !canEditDelete) return;

                              if (v == 'edit') {
                                await _editLatestSaleForShop(r.shop, r.day, endExcl);
                              }
                              if (v == 'delete') {
                                await _deleteLatestSaleForShop(r.shop, r.day, endExcl);
                              }
                              if (v == 'compare') {
                                await _compareWithTransactions(r.shop, r.day, endExcl);
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
      ),
    );
  }

  // --------------------- AGGREGATE TABLE (per-shop) ---------------------
  Widget _tableStreamAggregate({
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
                final rows = _aggregateRows(
                  docs.map((d) => app.mapSaleDoc(d)).where((m) {
                    final dt = m['createdAt'] as DateTime;
                    return !dt.isBefore(from) && dt.isBefore(to);
                  }).toList(),
                  allShops,
                );
                return _buildTableAggregate(rows);
              },
            );
          }
          return Center(child: Text('Error: $err'));
        }

        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snap.data!.docs;
        final rows = _aggregateRows(
          docs.map((d) => app.mapSaleDoc(d)).toList(),
          allShops,
        );
        return _buildTableAggregate(rows);
      },
    );
  }

  List<_AggRow> _aggregateRows(
    List<Map<String, dynamic>> sales,
    List<String> visibleShops,
  ) {
    final map = <String, _AggRow>{};
    for (final s in visibleShops) {
      map[s] = _AggRow(shop: s);
    }

    for (final m in sales) {
      final shop = (m['shop'] ?? '').toString();
      if (!visibleShops.contains(shop)) continue;

      double d(v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
      final cash = d(m['cash']), card = d(m['card']), other = d(m['other']);
      final total = d(m['total'] ?? (cash + card + other));
      final emp = (m['employee'] ?? m['addedBy'] ?? '').toString();
      final dt = (m['createdAt'] as DateTime?) ?? DateTime.now();

      final row = map[shop]!;
      row.cash += cash;
      row.card += card;
      row.other += other;
      row.total += total;
      if (row.lastSaleAt == null || dt.isAfter(row.lastSaleAt!)) {
        row.lastSaleAt = dt;
        row.lastEmployee = emp;
      }
    }

    final rows = map.values.toList()
      ..sort((a, b) => a.shop.compareTo(b.shop));
    return rows;
  }

  Widget _buildTableAggregate(List<_AggRow> rows) {
    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 680),
            child: DefaultTextStyle.merge(
              style: const TextStyle(fontSize: 12, height: 1.0),
              child: DataTableTheme(
                data: const DataTableThemeData(
                  dataRowMinHeight: 12,
                  dataRowMaxHeight: 26,
                  headingRowHeight: 28,
                  dividerThickness: 0.3,
                ),
                child: DataTable(
                  horizontalMargin: 8,
                  columnSpacing: 0,
                  columns: const [
                    DataColumn(label: Text('Shop')),
                    DataColumn(label: Text('Total')),
                    DataColumn(label: Text('Cash')),
                    DataColumn(label: Text('Card')),
                    DataColumn(label: Text('Other')),
                    DataColumn(label: Text('Last Employee')),
                  ],
                  rows: rows.map((r) {
                    final hasSale = (r.total > 0) || (r.cash > 0) || (r.card > 0) || (r.other > 0);
                    String moneyOrBlank(num v) => hasSale ? _fmtMoney(v) : '';
                    return DataRow(
                      cells: [
                        DataCell(Text(r.shop, overflow: TextOverflow.ellipsis)),
                        DataCell(Text(moneyOrBlank(r.total))),
                        DataCell(Text(moneyOrBlank(r.cash))),
                        DataCell(Text(moneyOrBlank(r.card))),
                        DataCell(Text(moneyOrBlank(r.other))),
                        DataCell(Text(hasSale ? (r.lastEmployee ?? '') : '', overflow: TextOverflow.ellipsis)),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --------------------- PER-SHOP DETAIL (unchanged core) ---------------------
  Future<void> _openShopSalesDetail(String shop, DateTime from, DateTime toExcl) async {
    final app = context.read<AppDataProvider>();
    final primary = app.buildSalesQuery(from: from, to: toExcl, shop: shop);

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
                            return !dt.isBefore(from) && dt.isBefore(toExcl);
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
    final endExcl = DateTime(to.year, to.month, to.day);
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
  // Monthly = 1st of that month to today (exclusive end)
  // Yearly  = Jan 1 of that year to today (exclusive end)
  (DateTime, DateTime) _computeRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_period == 'Date Range' && _range != null) {
      final start = DateTime(_range!.start.year, _range!.start.month, _range!.start.day);
      var end = DateTime(_range!.end.year, _range!.end.month, _range!.end.day);
      if (end.isAfter(today)) end = today;
      return (start, end.add(const Duration(days: 1)));
    }

    // ---- Anchor ko cap karo: future na ho
    final anchor = _anchorDate.isAfter(today)
        ? today
        : DateTime(_anchorDate.year, _anchorDate.month, _anchorDate.day);

    if (_period == 'Daily' || _period == 'Specific Date') {
      final start = anchor;
      final endExcl = anchor.add(const Duration(days: 1));
      return (start, endExcl);
    }

    if (_period == 'Weekly') {
      // 7 din ka rolling window: [anchor-6 .. anchor]
      final end = anchor;
      final start = end.subtract(const Duration(days: 6));
      return (start, end.add(const Duration(days: 1)));
    }

    if (_period == 'Monthly') {
      // month of anchor: [1st of (anchor.month) .. min(today, endOfMonth)]
      final start = DateTime(anchor.year, anchor.month, 1);
      final startNextMonth = DateTime(anchor.year, anchor.month + 1, 1);
      final endOfMonth = startNextMonth.subtract(const Duration(days: 1));
      final end = endOfMonth.isAfter(today) ? today : endOfMonth;
      return (start, end.add(const Duration(days: 1)));
    }

    if (_period == 'Yearly') {
      // year of anchor: [Jan 1 (anchor.year) .. min(today, Dec 31)]
      final start = DateTime(anchor.year, 1, 1);
      final endOfYear = DateTime(anchor.year + 1, 1, 1).subtract(const Duration(days: 1));
      final end = endOfYear.isAfter(today) ? today : endOfYear;
      return (start, end.add(const Duration(days: 1)));
    }

    // fallback (Daily)
    final start = anchor;
    return (start, start.add(const Duration(days: 1)));
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
