// lib/screens/sales_screen.dart
import 'dart:io';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/app_data_provider.dart';
import 'add_sale_screen.dart';
import 'shop_selection_screen.dart';

// ---------- Per-day row model ----------
class _DayRow {
  _DayRow({required this.shop, required this.day});
  final String shop;           // shop name
  final DateTime day;          // midnight
  double cash = 0.0;
  double card = 0.0;
  double other = 0.0;
  double total = 0.0;
  String? employee;            // last employee for that day
  DateTime? lastSaleAt;
  bool selected = false;       // for bulk delete selection
}

// ---------- Period aggregate row model ----------
class _AggRow {
  _AggRow({required this.shop});
  final String shop;
  double cash = 0.0, card = 0.0, other = 0.0, total = 0.0;
}

enum _ViewMode { aggregate, detailed }

// ===============================================================
// Screen
// ===============================================================
class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key, this.initialShopName});
  final String? initialShopName;

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  // ---- Filters ----
  String _period = 'Daily';
  String _selectedShop = 'All';
  DateTime _anchorDate = DateTime.now();
  DateTimeRange? _range;
  _ViewMode _view = _ViewMode.aggregate;

  // export cache
  List<_DayRow> _exportRows = [];
  DateTime? _lastFrom;
  DateTime? _lastTo;

  // selections
  final _selectedKeys = <String>{};      // detailed: "shop|yyyy-MM-dd"
  final _selectedAggShops = <String>{};  // aggregate: shop names

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _anchorDate = DateTime(n.year, n.month, n.day);
    final init = (widget.initialShopName ?? '').trim();
    if (init.isNotEmpty) _selectedShop = init;
  }

  // --------------------- UI ---------------------
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();

    final shops = app.shops
        .where((s) => (s['isDeleted'] ?? false) != true)
        .map((s) => (s['name'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList()
      ..sort();

    if (_selectedShop != 'All' && !shops.contains(_selectedShop)) {
      _selectedShop = 'All';
    }
    final allShopOptions = ['All', ...shops];
    final visibleShops = (_selectedShop != 'All' && shops.contains(_selectedShop))
        ? <String>[_selectedShop]
        : shops;

    final (from, toExcl) = _computeRange(); // [from .. to) exclusive
    final periodLabel = _labelForRange(from, toExcl);

    final canAdmin = app.isAdmin == true || app.isManager == true;

    final hasAnySelection = _view == _ViewMode.aggregate
        ? _selectedAggShops.isNotEmpty
        : _selectedKeys.isNotEmpty;

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
          if (canAdmin)
            IconButton(
              tooltip: 'Bulk Upload (CSV/XLSX)',
              onPressed: _pickAndUploadFile,
              icon: const Icon(Icons.file_upload_outlined),
            ),
          if (canAdmin)
            IconButton(
              tooltip: 'Bulk Delete (selected)',
              onPressed: hasAnySelection
                  ? () {
                      if (_view == _ViewMode.aggregate) {
                        _confirmBulkDeleteAggregate();
                      } else {
                        _confirmBulkDelete();
                      }
                    }
                  : null,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
          IconButton(
            tooltip: 'Add Sale',
            onPressed: () {
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

          // -------------- Filters (two rows) --------------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _filtersRow(allShopOptions, periodLabel),
          ),

          const SizedBox(height: 6),

          // -------------- Table --------------
          Expanded(
            child: _tableStream(
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

  // --------------------- FILTERS ---------------------
  Widget _filtersRow(List<String> shopOptions, String periodLabel) {
    // row 1: Shop | Period
    // row 2: Type of Sale | Date
    final theme = Theme.of(context);
    final isRange = _period == 'Date Range';
    final isSpecific = _period == 'Specific Date';
    final rowGap = const SizedBox(height: 8);

    return LayoutBuilder(builder: (ctx, cs) {
      final half = (cs.maxWidth - 12) / 2; // a little breathing room

      final shopField = SizedBox(
        width: half,
        child: DropdownButtonFormField<String>(
          isDense: true,
          isExpanded: true,
          value: shopOptions.contains(_selectedShop) ? _selectedShop : 'All',
          items: shopOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) => setState(() => _selectedShop = v ?? 'All'),
          decoration: const InputDecoration(labelText: 'Shop', isDense: true, border: UnderlineInputBorder()),
        ),
      );

      final periodField = SizedBox(
        width: half,
        child: DropdownButtonFormField<String>(
          isDense: true,
          isExpanded: true,
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
              if (_period == 'Yearly') _anchorDate = DateTime(today.year, 1, 1);
              if (_period != 'Date Range') _range = null;
            });
            if (!mounted) return;
            if (_period == 'Specific Date') {
              await _pickAnchorDate();
            } else if (_period == 'Date Range') {
              await _pickRange();
            }
          },
          decoration: const InputDecoration(labelText: 'Period', isDense: true, border: UnderlineInputBorder()),
        ),
      );

      final typeField = SizedBox(
        width: half,
        child: DropdownButtonFormField<_ViewMode>(
          isDense: true,
          isExpanded: true,
          value: _view,
          items: const [
            DropdownMenuItem(value: _ViewMode.aggregate, child: Text('Aggregate View')),
            DropdownMenuItem(value: _ViewMode.detailed, child: Text('Detailed View')),
          ],
          onChanged: (v) => setState(() => _view = v ?? _ViewMode.detailed),
          decoration: const InputDecoration(labelText: 'Type of Sale', isDense: true, border: UnderlineInputBorder()),
        ),
      );

      final dateField = SizedBox(
        width: half,
        child: isRange
            ? _rangePickerBar(theme)
            : _datePickerBar(theme, periodLabel, isSpecific),
      );

      return Column(
        children: [
          Row(children: [shopField, const SizedBox(width: 12), periodField]),
          rowGap,
          Row(children: [typeField, const SizedBox(width: 12), dateField]),
        ],
      );
    });
  }

  Widget _datePickerBar(ThemeData theme, String periodLabel, bool isSpecific) {
    return Row(
      children: [
        _navIconButton(Icons.chevron_left, () => _shiftAnchor(-1)),
        const SizedBox(width: 4),
        Expanded(
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
      children: [
        _navIconButton(Icons.chevron_left, () => _shiftRange(-1)),
        const SizedBox(width: 4),
        Expanded(
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

  Future<void> _pickAnchorDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchorDate,
      firstDate: DateTime(2022, 1, 1),
      lastDate: DateTime(now.year, now.month, now.day), // no future
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
        d = d.add(Duration(days: dir));
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
            // fallback once
            return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
              future: app.buildSalesQueryLoose(shop: filterByShop ? selectedShop : null).get(),
              builder: (ctx, fs) {
                if (fs.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (fs.hasError) return Center(child: Text('Error: ${fs.error}'));
                final docs = fs.data?.docs ?? const [];
                final mapped = docs.map((d) => app.mapSaleDoc(d)).where((m) {
                  final dt = m['createdAt'] as DateTime;
                  return !dt.isBefore(from) && dt.isBefore(to);
                }).toList();

                return _view == _ViewMode.aggregate
                    ? _buildTableAggregate(_rowsAggregate(mapped, allShops, from, to), from, to)
                    : _buildTablePerDay(_rowsPerDay(mapped, allShops, from, to));
              },
            );
          }
          return Center(child: Text('Error: $err'));
        }

        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snap.data!.docs;
        final mapped = docs.map((d) => app.mapSaleDoc(d)).toList();

        return _view == _ViewMode.aggregate
            ? _buildTableAggregate(_rowsAggregate(mapped, allShops, from, to), from, to)
            : _buildTablePerDay(_rowsPerDay(mapped, allShops, from, to));
      },
    );
  }

  // -------- detailed (day x shop) --------
  List<_DayRow> _rowsPerDay(
    List<Map<String, dynamic>> sales,
    List<String> visibleShops,
    DateTime from,
    DateTime to,
  ) {
    final byKey = <String, _DayRow>{};
    String k(String shop, DateTime d) => '${shop}_${DateFormat('yyyy-MM-dd').format(d)}';

    // init all (day × shop) so empty lines appear
    for (int i = 0; i < to.difference(from).inDays; i++) {
      final day = DateTime(from.year, from.month, from.day).add(Duration(days: i));
      for (final shop in visibleShops) {
        byKey[k(shop, day)] = _DayRow(shop: shop, day: day);
      }
    }

    // fill with totals
    for (final m in sales) {
      final shop = (m['shop'] ?? '').toString();
      if (!visibleShops.contains(shop)) continue;

      final dt = (m['createdAt'] as DateTime?) ?? DateTime.now();
      final day = DateTime(dt.year, dt.month, dt.day);
      if (day.isBefore(from) || !day.isBefore(to)) continue;

      final key = k(shop, day);
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
        final c = b.day.compareTo(a.day); // latest first
        if (c != 0) return c;
        return a.shop.compareTo(b.shop);
      });
    return rows;
  }

  // -------- aggregate (per shop for selected period) --------
  List<_AggRow> _rowsAggregate(
    List<Map<String, dynamic>> sales,
    List<String> visibleShops,
    DateTime from,
    DateTime to,
  ) {
    final byShop = {for (final s in visibleShops) s: _AggRow(shop: s)};

    for (final m in sales) {
      final shop = (m['shop'] ?? '').toString();
      if (!byShop.containsKey(shop)) continue;

      final dt = (m['createdAt'] as DateTime?) ?? DateTime.now();
      if (dt.isBefore(from) || !dt.isBefore(to)) continue;

      double d(v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
      final cash = d(m['cash']), card = d(m['card']), other = d(m['other']);
      final total = d(m['total'] ?? (cash + card + other));

      final r = byShop[shop]!;
      r.cash += cash; r.card += card; r.other += other; r.total += total;
    }

    final rows = byShop.values.toList()..sort((a, b) => a.shop.compareTo(b.shop));
    return rows;
  }

  Widget _buildTableAggregate(List<_AggRow> rows, DateTime from, DateTime toExcl) {
    // widths → keep aligned on small phones too
    const wChk = 42.0; // checkbox col
    const wDate = 120.0;
    const wShop = 150.0;
    const wMoney = 90.0;
    const wEmployee = 140.0;
    const wActions = 70.0;

    final rangeLabel = _labelForRange(from, toExcl);

    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: wChk + wDate + wShop + (wMoney * 4) + wEmployee + wActions + 24,
          ),
          child: Scrollbar(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: DataTableTheme(
                data: const DataTableThemeData(
                  dataRowMinHeight: 34,
                  dataRowMaxHeight: 38,
                  headingRowHeight: 36,
                  dividerThickness: .35,
                ),
                child: DataTable(
                  horizontalMargin: 2,
                  columnSpacing: 2,
                  showCheckboxColumn: false,
                  columns: const [
                    DataColumn(label: Text('')),                // selection
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
                    Widget moneyCell(String text) => SizedBox(
                      width: wMoney,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 2), // small left gap
                        child: Align(alignment: Alignment.centerLeft, child: Text(text)),
                      ),
                    );

                    final isSelected = _selectedAggShops.contains(r.shop);

                    return DataRow(
                      selected: isSelected,
                      onSelectChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedAggShops.add(r.shop);
                          } else {
                            _selectedAggShops.remove(r.shop);
                          }
                        });
                      },
                      cells: [
                        DataCell(SizedBox(
                          width: wChk,
                          child: Checkbox(
                            value: isSelected,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) _selectedAggShops.add(r.shop);
                                else _selectedAggShops.remove(r.shop);
                              });
                            },
                          ),
                        )),
                        DataCell(SizedBox(width: wDate, child: Text(rangeLabel, overflow: TextOverflow.ellipsis))),
                        DataCell(SizedBox(width: wShop, child: Text(r.shop, overflow: TextOverflow.ellipsis))),
                        DataCell(moneyCell(_fmtMoney(r.total))),
                        DataCell(moneyCell(_fmtMoney(r.cash))),
                        DataCell(moneyCell(_fmtMoney(r.card))),
                        DataCell(moneyCell(_fmtMoney(r.other))),
                        const DataCell(SizedBox(width: wEmployee)), // blank
                        DataCell(SizedBox(
                          width: wActions,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              onSelected: (v) {
                                final start = DateTime(from.year, from.month, from.day);
                                if (v == 'view') {
                                  _openShopSalesDetail(r.shop, start, toExcl);
                                } else if (v == 'compare') {
                                  _compareWithTransactions(r.shop, start, toExcl);
                                }
                              },
                              itemBuilder: (ctx) => const [
                                PopupMenuItem(value: 'view', child: Text('View sales')),
                                PopupMenuItem(value: 'compare', child: Text('Compare with Tx')),
                              ],
                              child: const Icon(Icons.more_horiz, size: 18),
                            ),
                          ),
                        )),
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

    // widths → keep aligned on small phones too
    const wChk = 42.0; // checkbox col
    const wDate = 120.0;
    const wShop = 150.0;
    const wMoney = 90.0;
    const wEmployee = 140.0;
    const wActions = 70.0;

    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth:
              wChk + wDate + wShop + (wMoney * 4) + wEmployee + wActions + 24),
          child: Scrollbar(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: DataTableTheme(
                data: const DataTableThemeData(
                  dataRowMinHeight: 34,
                  dataRowMaxHeight: 38,
                  headingRowHeight: 36,
                  dividerThickness: .35,
                ),
                child: DataTable(
                  horizontalMargin: 2,
                  columnSpacing: 2,
                  showCheckboxColumn: false,
                  columns: const [
                    DataColumn(label: Text('')),                // selection
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
                    final key = '${r.shop}|${DateFormat('yyyy-MM-dd').format(r.day)}';
                    final selected = _selectedKeys.contains(key);
                    final hasSale = (r.total > 0) || (r.cash > 0) || (r.card > 0) || (r.other > 0);
                    String moneyOrBlank(num v) => hasSale ? _fmtMoney(v) : '';
                    final dateText = DateFormat('dd MMM, yyyy').format(r.day);

                    Widget moneyCell(String text) => SizedBox(
                      width: wMoney,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 2), // small left gap
                        child: Align(alignment: Alignment.centerLeft, child: Text(text)),
                      ),
                    );

                    return DataRow(
                      selected: selected,
                      onSelectChanged: canEditDelete ? (v) {
                        setState(() {
                          if (v == true) { _selectedKeys.add(key); } else { _selectedKeys.remove(key); }
                        });
                      } : null,
                      cells: [
                        DataCell(SizedBox(
                          width: wChk,
                          child: Checkbox(
                            value: selected,
                            onChanged: canEditDelete ? (v) {
                              setState(() {
                                if (v == true) _selectedKeys.add(key); else _selectedKeys.remove(key);
                              });
                            } : null,
                          ),
                        )),
                        DataCell(SizedBox(width: wDate, child: Text(dateText))),
                        DataCell(SizedBox(width: wShop, child: Text(r.shop, overflow: TextOverflow.ellipsis))),
                        DataCell(moneyCell(moneyOrBlank(r.total))),
                        DataCell(moneyCell(moneyOrBlank(r.cash))),
                        DataCell(moneyCell(moneyOrBlank(r.card))),
                        DataCell(moneyCell(moneyOrBlank(r.other))),
                        DataCell(SizedBox(width: wEmployee, child: Text(hasSale ? (r.employee ?? '') : ''))),
                        DataCell(SizedBox(
                          width: wActions,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: canEditDelete
                                ? PopupMenuButton<String>(
                                    padding: EdgeInsets.zero,
                                    onSelected: (v) {
                                      final end = r.day.add(const Duration(days: 1));
                                      if (v == 'view') {
                                        _openShopSalesDetail(r.shop, r.day, end);
                                      } else if (v == 'edit_latest') {
                                        _editLatestSaleForShop(r.shop, r.day, end);
                                      } else if (v == 'delete_latest') {
                                        _deleteLatestSaleForShop(r.shop, r.day, end);
                                      } else if (v == 'compare') {
                                        _compareWithTransactions(r.shop, r.day, end);
                                      }
                                    },
                                    itemBuilder: (ctx) => const [
                                      PopupMenuItem(value: 'view', child: Text('View sales')),
                                      PopupMenuItem(value: 'edit_latest', child: Text('Edit latest')),
                                      PopupMenuItem(value: 'delete_latest', child: Text('Delete latest')),
                                      PopupMenuItem(value: 'compare', child: Text('Compare with Tx')),
                                    ],
                                    child: const Icon(Icons.more_horiz, size: 18),
                                  )
                                : IconButton(
                                    tooltip: 'View sales',
                                    icon: const Icon(Icons.visibility_outlined),
                                    onPressed: () => _openShopSalesDetail(
                                      r.shop, r.day, r.day.add(const Duration(days: 1))),
                                  ),
                          ),
                        )),
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

  // --------------------- PER-SHOP DETAIL ---------------------
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
              if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());

              final rows = snap.data!.docs.map((d) => app.mapSaleDoc(d)).toList()
                ..sort((a, b) => (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime));

              final app2 = context.read<AppDataProvider>();
              final canEditDelete = app2.isAdmin == true || app2.isManager == true;

              return Scaffold(
                appBar: AppBar(title: Text('Sales • $shop')),
                body: rows.isEmpty
                    ? const Center(child: Text('No sales found for this day'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(10),
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (_, i) {
                          final s = rows[i];
                          final when = DateFormat('dd MMM, yyyy – hh:mm a').format(s['createdAt']);
                          final tot = ((s['total'] as num?)?.toDouble() ?? 0).toStringAsFixed(2);
                          final emp = (s['employee'] ?? '').toString();
                          return Card(
                            margin: EdgeInsets.zero,
                            child: ListTile(
                              dense: true,
                              title: Text('\$ $tot', style: const TextStyle(fontWeight: FontWeight.w600)),
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
            },
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _fetchLatestSaleForShop(String shop, DateTime from, DateTime to) async {
    final app = context.read<AppDataProvider>();
    try {
      final snap = await app.buildSalesQuery(from: from, to: to, shop: shop).limit(1).get();
      if (snap.docs.isEmpty) return null;
      return app.mapSaleDoc(snap.docs.first);
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        final fs = await app.buildSalesQueryLoose(shop: shop).get();
        final items = fs.docs.map((d) => app.mapSaleDoc(d)).where((m) {
          final dt = m['createdAt'] as DateTime;
          return !dt.isBefore(from) && dt.isBefore(to);
        }).toList()
          ..sort((a, b) => (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime));
        return items.isEmpty ? null : items.first;
      }
      rethrow;
    }
  }

  Future<void> _editLatestSaleForShop(String shop, DateTime from, DateTime to) async {
    final messenger = ScaffoldMessenger.of(context);
    final s = await _fetchLatestSaleForShop(shop, from, to);
    if (s == null) {
      messenger.showSnackBar(const SnackBar(content: Text('No sale to edit for this day')));
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddSaleScreen(existingSale: s)));
  }

  Future<void> _deleteLatestSaleForShop(String shop, DateTime from, DateTime to) async {
    final app = context.read<AppDataProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final s = await _fetchLatestSaleForShop(shop, from, to);
    if (s == null) {
      messenger.showSnackBar(const SnackBar(content: Text('No sale to delete for this day')));
      return;
    }

    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete latest sale?'),
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
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddSaleScreen(existingSale: sale)));
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
      messenger.showSnackBar(const SnackBar(content: Text('Sale deleted')));
    }
  }

  // --------------------- BULK DELETE (selected rows - DETAILED) ---------------------
  Future<void> _confirmBulkDelete() async {
    if (_selectedKeys.isEmpty) return;
    final app = context.read<AppDataProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete selected days?'),
        content: Text('This will delete the **latest sale** for each selected (shop, day).\nSelected: ${_selectedKeys.length}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    final messenger = ScaffoldMessenger.of(context);
    int deleted = 0;
    for (final k in _selectedKeys) {
      final p = k.split('|');
      if (p.length != 2) continue;
      final shop = p[0];
      final day = DateTime.tryParse(p[1]) ?? DateTime.now();
      final s = await _fetchLatestSaleForShop(shop, day, day.add(const Duration(days: 1)));
      if (s != null) {
        await app.deleteSale(s['id'].toString());
        deleted++;
      }
    }
    setState(() => _selectedKeys.clear());
    messenger.showSnackBar(SnackBar(content: Text('Deleted $deleted sale(s)')));
  }

  // --------------------- BULK DELETE (selected shops - AGGREGATE) ---------------------
  Future<void> _confirmBulkDeleteAggregate() async {
    if (_selectedAggShops.isEmpty) return;
    final app = context.read<AppDataProvider>();
    final (from, toExcl) = _computeRange();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete selected period data?'),
        content: Text(
          'This will delete ALL sales in this period for the selected shop(s).\n\n'
          'Period: ${_labelForRange(from, toExcl)}\n'
          'Selected shops: ${_selectedAggShops.length}\n\n'
          'This cannot be undone.'
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    int deleted = 0;

    WriteBatch? batch;
    int inBatch = 0;

    Future<void> commit() async {
      if (batch != null && inBatch > 0) {
        await batch!.commit();
      }
      batch = FirebaseFirestore.instance.batch();
      inBatch = 0;
    }

    await commit();

    try {
      for (final shop in _selectedAggShops) {
        final q = app.buildSalesQuery(from: from, to: toExcl, shop: shop);
        final snap = await q.get();
        for (final d in snap.docs) {
          batch!.delete(d.reference);
          inBatch++; deleted++;
          if (inBatch >= 400) {
            await commit();
          }
        }
      }
      await commit();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _selectedAggShops.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted $deleted item(s)')),
    );
  }

  // --------------------- BULK UPLOAD ---------------------
  Future<void> _pickAndUploadFile() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx', 'xls'],
    );
    if (res == null || res.files.isEmpty) return;

    final f = res.files.single;
    List<List<dynamic>> rows;

    try {
      if ((f.extension ?? '').toLowerCase() == 'csv') {
        final text = utf8.decode(f.bytes ?? await File(f.path!).readAsBytes());
        rows = const CsvToListConverter().convert(text);
      } else {
        final bytes = f.bytes ?? await File(f.path!).readAsBytes();
        final book = xls.Excel.decodeBytes(bytes);
        final sheet = book.tables.values.first;
        rows = sheet!.rows.map((r) => r.map((c) => c?.value).toList()).toList();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Read failed: $e')));
      return;
    }

    final normalized = _normalizeUploadRows(rows);
    if (normalized.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No valid rows found.')));
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm bulk upload?'),
        content: Text('Valid rows: ${normalized.length}\n\nHeaders must be:\nDate, Shop, Total, Cash, Card, Other, Employee'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Upload')),
        ],
      ),
    );
    if (ok != true) return;

    final app = context.read<AppDataProvider>();
    int added = 0, skipped = 0;

    // batch in chunks of 400 (Firestore limit 500)
    WriteBatch? batch;
    int inBatch = 0;

    Future<void> commit() async {
      if (batch != null && inBatch > 0) {
        await batch!.commit();
      }
      batch = FirebaseFirestore.instance.batch();
      inBatch = 0;
    }

    await commit(); // create first

    for (final r in normalized) {
      final day = r['day'] as DateTime;
      final shop = r['shop'] as String;
      final dayKey = app.dayKeyOf(day);

      // check duplicate (one per shop per day)
      final dupQ = FirebaseFirestore.instance
          .collection('sales')
          .where('shop', isEqualTo: shop)
          .where('dayKey', isEqualTo: dayKey)
          .limit(1);
      final dupSnap = await dupQ.get();
      if (dupSnap.docs.isNotEmpty) {
        skipped++;
        continue;
      }

      final noon = DateTime(day.year, day.month, day.day, 12);
      final data = {
        'shop': shop,
        'employee': r['employee'],
        'cash': (r['cash'] as num).toDouble(),
        'card': (r['card'] as num).toDouble(),
        'other': (r['other'] as num).toDouble(),
        'total': (r['total'] as num).toDouble(),
        'createdAt': Timestamp.fromDate(noon),
        'dayKey': dayKey,
        'source': 'bulk_upload',
      };

      final ref = FirebaseFirestore.instance.collection('sales').doc();
      batch!.set(ref, data);
      inBatch++; added++;

      if (inBatch >= 400) {
        await commit();
      }
    }
    await commit();

    await app.fetchSales();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Upload complete: $added added, $skipped skipped (duplicates)')),
    );
  }

  List<Map<String, dynamic>> _normalizeUploadRows(List<List<dynamic>> rows) {
    // Expect header row:
    // Date, Shop, Total, Cash, Card, Other, Employee
    if (rows.isEmpty) return [];

    // find first non-empty header row
    int headerIndex = 0;
    while (headerIndex < rows.length && (rows[headerIndex].where((c) => '$c'.trim().isNotEmpty).isEmpty)) {
      headerIndex++;
    }
    if (headerIndex >= rows.length) return [];

    final header = rows[headerIndex].map((e) => (e ?? '').toString().trim().toLowerCase()).toList();
    int idxDate = header.indexOf('date');
    int idxShop = header.indexOf('shop');
    int idxTotal = header.indexOf('total');
    int idxCash = header.indexOf('cash');
    int idxCard = header.indexOf('card');
    int idxOther = header.indexOf('other');
    int idxEmp = header.indexOf('employee');

    if ([idxDate, idxShop, idxTotal, idxCash, idxCard, idxOther, idxEmp].any((i) => i < 0)) {
      return [];
    }

    final out = <Map<String, dynamic>>[];
    for (int i = headerIndex + 1; i < rows.length; i++) {
      final r = rows[i];
      if (r.isEmpty) continue;

      String s(int idx) => (idx < r.length ? (r[idx] ?? '').toString() : '').trim();
      double d(int idx) {
        final raw = idx < r.length ? r[idx] : null;
        if (raw is num) return raw.toDouble();
        return double.tryParse('$raw'.replaceAll(',', '')) ?? 0.0;
      }

      // parse date (accept dd/MM/yyyy, yyyy-MM-dd, dd MMM, yyyy)
      DateTime? day;
      final ds = s(idxDate);
      final tryFormats = ['yyyy-MM-dd', 'dd/MM/yyyy', 'MM/dd/yyyy', 'dd MMM, yyyy', 'dd MMM yyyy'];
      for (final f in tryFormats) {
        try {
          day ??= DateFormat(f).parseStrict(ds);
        } catch (_) {}
      }
      day ??= DateTime.tryParse(ds);
      if (day == null) continue;
      day = DateTime(day.year, day.month, day.day);

      final shop = s(idxShop);
      if (shop.isEmpty) continue;

      final total = d(idxTotal);
      final cash = d(idxCash);
      final card = d(idxCard);
      final other = d(idxOther);
      final emp = s(idxEmp);

      out.add({
        'day': day,
        'shop': shop,
        'total': total,
        'cash': cash,
        'card': card,
        'other': other,
        'employee': emp,
      });
    }
    return out;
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

    final salesSnap = await app.buildSalesQuery(from: start, to: endExcl, shop: shop).get();

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
                final err = await app.postDailySaleFromTransactions(shopName: shop, day: start);
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_period == 'Date Range' && _range != null) {
      final start = DateTime(_range!.start.year, _range!.start.month, _range!.start.day);
      var end = DateTime(_range!.end.year, _range!.end.month, _range!.end.day);
      if (end.isAfter(today)) end = today;
      return (start, end.add(const Duration(days: 1)));
    }

    final anchor = _anchorDate.isAfter(today)
        ? today
        : DateTime(_anchorDate.year, _anchorDate.month, _anchorDate.day);

    if (_period == 'Daily' || _period == 'Specific Date') {
      final start = anchor;
      final endExcl = anchor.add(const Duration(days: 1));
      return (start, endExcl);
    }
    if (_period == 'Weekly') {
      final end = anchor;
      final start = end.subtract(const Duration(days: 6));
      return (start, end.add(const Duration(days: 1)));
    }
    if (_period == 'Monthly') {
      final start = DateTime(anchor.year, anchor.month, 1);
      final endOfMonth = DateTime(anchor.year, anchor.month + 1, 1).subtract(const Duration(days: 1));
      final end = endOfMonth.isAfter(today) ? today : endOfMonth;
      return (start, end.add(const Duration(days: 1)));
    }
    if (_period == 'Yearly') {
      final start = DateTime(anchor.year, 1, 1);
      final endOfYear = DateTime(anchor.year + 1, 1, 1).subtract(const Duration(days: 1));
      final end = endOfYear.isAfter(today) ? today : endOfYear;
      return (start, end.add(const Duration(days: 1)));
    }

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

  // --------------------- EXPORTS ---------------------
  Future<void> _exportCsv() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_exportRows.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Nothing to export')));
      return;
    }

    final b = StringBuffer();
    b.writeln('Date,Shop,Total,Cash,Card,Other,Employee');
    for (final r in _exportRows) {
      final d = DateFormat('dd MMM, yyyy').format(r.day);
      b.writeln([
        _csvEsc(d),
        _csvEsc(r.shop),
        r.total.toStringAsFixed(2),
        r.cash.toStringAsFixed(2),
        r.card.toStringAsFixed(2),
        r.other.toStringAsFixed(2),
        _csvEsc(r.employee ?? ''),
      ].join(','));
    }

    final dir = await getTemporaryDirectory();
    final name = 'sales_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
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
      messenger.showSnackBar(const SnackBar(content: Text('Nothing to export')));
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
              final d = DateFormat('dd MMM, yyyy').format(r.day);
              return [
                d,
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
    final name = 'sales_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: name);
  }
}
