// lib/screens/cash_collect_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:csv/csv.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // only for optional bulk fallback (not required)

import '../providers/app_data_provider.dart';

const _neon = Color(0xFF00FFC6);
const _danger = Color(0xFFFF6B6B);
const _mutedStroke = Color(0x22FFFFFF);
const _mutedFill = Color(0x12FFFFFF);

class CashCollectScreen extends StatefulWidget {
  const CashCollectScreen({super.key, this.initialShopName});
  final String? initialShopName;

  @override
  State<CashCollectScreen> createState() => _CashCollectScreenState();
}

class _CashCollectScreenState extends State<CashCollectScreen> {
  final _df = DateFormat('dd MMM, yyyy');

  String _shopFilter = 'All';
  _Period _period = _Period.daily;
  DateTime _anchor = DateTime.now();
  DateTimeRange? _range;

  List<_RowVM> _rows = const [];
  AppDataProvider? _appSub;

  static const double _kHeaderHeight = 34;
  static const double _kGapBelowHeader = 4;

  bool _loading = false; // top progress bar
  bool _navBusy = false; // debounce arrows

  @override
  void initState() {
    super.initState();
    final init = (widget.initialShopName ?? '').trim();
    if (init.isNotEmpty) _shopFilter = init;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final app = context.read<AppDataProvider>();
      if ((app.shops as List?)?.isEmpty ?? true) await app.fetchShops();
      if ((app.sales as List?)?.isEmpty ?? true) await app.fetchSales();

      _appSub = app..addListener(_rebuild);
      _rebuild();
    });
  }

  @override
  void dispose() {
    _appSub?.removeListener(_rebuild);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = context.read<AppDataProvider>();
    if (!identical(app, _appSub)) {
      _appSub?.removeListener(_rebuild);
      _appSub = app..addListener(_rebuild);
    }
  }

Future<void> _setCollected(_RowVM row, bool collected) async {
  final app = context.read<AppDataProvider>();
  final user = app.loggedInUser ?? {};

  await app.setCashCollected(
    shopId: row.shopId,
    shopName: row.shopName,
    from: row.day,
    to: row.day,
    collected: collected,
    cashAmount: row.cash.toDouble(),
    byUserId: (user['uid'] ?? '').toString(),
    byUserName: (user['name'] ?? user['email'] ?? '').toString(),
  );

  setState(() => row.collected = collected);

  // optional: rows + totals fresh karne ke liye
  await _rebuild();
}

  Future<void> _rebuild() async {
    final app = context.read<AppDataProvider>();
    setState(() => _loading = true);
    final rows = await _buildRowsFast(app);
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  // ================== FAST ROW BUILDER ==================
  /// Heavy-speedup:
  ///  - Pre-index sales in a map: key = shopName|yyyy-mm-dd → (hasSale, cashSum)
  ///  - Only call isCashCollected() for rows where hasSale||cash>0
  ///  - Batch those calls in chunks of 25 (parallel)
  Future<List<_RowVM>> _buildRowsFast(AppDataProvider app) async {
    final allShopNames = (app.shops as List? ?? const [])
        .where((e) => (e['isDeleted'] ?? false) != true)
        .map((e) => (e['name'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final shops = _shopFilter == 'All'
        ? allShopNames
        : allShopNames.where((s) => s.toLowerCase() == _shopFilter.toLowerCase()).toList();

    final (DateTime from, DateTime to) = _periodBounds();
    final days = <DateTime>[];
    for (DateTime d = from; !d.isAfter(to); d = DateTime(d.year, d.month, d.day).add(const Duration(days: 1))) {
      days.add(DateTime(d.year, d.month, d.day));
    }

    // --- index sales quickly ---
    final saleIndex = <String, _SaleAgg>{};
    String k(String shop, DateTime d) =>
        '${shop.toLowerCase()}|${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    // Only scan needed window to avoid full scan for yearly
    for (final s in (app.sales as List? ?? const [])) {
      final shop = (s['shop'] ?? s['shopName'] ?? '').toString().trim();
      if (shop.isEmpty) continue;
      if (_shopFilter != 'All' && shop.toLowerCase() != _shopFilter.toLowerCase()) continue;

      // saleDate stored as yyyy-MM-dd
      final sd = (s['saleDate'] ?? '').toString();
      if (sd.length < 10) continue;
      final y = int.tryParse(sd.substring(0, 4));
      final m = int.tryParse(sd.substring(5, 7));
      final d = int.tryParse(sd.substring(8, 10));
      if (y == null || m == null || d == null) continue;
      final day = DateTime(y, m, d);
      if (day.isBefore(from) || day.isAfter(to)) continue;

      final key = k(shop, day);
      final agg = saleIndex.putIfAbsent(key, () => _SaleAgg());
      double _num(v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
      agg.cash += _num(s['cash']);
      agg.card += _num(s['card']);
      agg.other += _num(s['other']);
      agg.total += _num(s['total'] ?? 0);
      agg.hasSale = true;
    }

    // --- build base rows (no collected yet) ---
    final rows = <_RowVM>[];
    for (final day in days.reversed) {
      for (final shop in shops) {
        final key = k(shop, day);
        final agg = saleIndex[key];
        final hasSale = agg?.hasSale ?? false;
        final cash = agg?.cash ?? 0;

        rows.add(_RowVM(
          shopId: app.shopIdForName(shop) ?? '',
          shopName: shop,
          day: day,
          cash: cash,
          hasSale: hasSale,
          collected: false, // set later (only for relevant rows)
        ));
      }
    }

    // --- resolve collected only where needed ---
    final relevant = rows.where((r) => r.hasSale || r.cash > 0).toList();
    const chunk = 25;
    for (int i = 0; i < relevant.length; i += chunk) {
      final part = relevant.sublist(i, (i + chunk).clamp(0, relevant.length));
      // run in parallel (25 at a time)
      await Future.wait(part.map((r) async {
        try {
          final ok = await app.isCashCollected(shopId: r.shopId, from: r.day, to: r.day);
          r.collected = ok;
        } catch (_) {
          // keep false on error
        }
      }));
    }

    return rows;
  }

  // ================== TOTALS ==================
  ({double total, double picked, double notPicked}) _rollup() {
    double total = 0, picked = 0, notPicked = 0;
    for (final r in _rows) {
      if (r.hasSale) {
        total += r.cash.toDouble();
        if (r.collected) picked += r.cash.toDouble();
      }
    }
    notPicked = (total - picked).clamp(0.0, double.infinity);
    return (total: total, picked: picked, notPicked: notPicked);
  }

  Widget _totalsBar() {
    final t = _rollup();
    String m(double v) => v.toStringAsFixed(2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _mutedFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _mutedStroke),
      ),
      child: Row(
        children: [
          Expanded(child: _pill('Total Cash', '\$ ${m(t.total)}')),
          const SizedBox(width: 8),
          Expanded(child: _pill('Cash Picked', '\$ ${m(t.picked)}')),
          const SizedBox(width: 8),
          Expanded(child: _pill('Cash Not Picked', '\$ ${m(t.notPicked)}')),
        ],
      ),
    );
  }

  Widget _pill(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  // ================== EXPORTS ==================
  Future<void> _exportCSV() async {
    if (_rows.isEmpty) return;
    final data = <List<dynamic>>[
      ['Shop', 'Date', 'Cash', 'Collected'],
      ..._rows.map((r) => [
            r.shopName,
            DateFormat('yyyy-MM-dd').format(r.day),
            r.cash.toStringAsFixed(2),
            r.collected ? 'Yes' : 'No'
          ]),
    ];
    final csv = const ListToCsvConverter().convert(data);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/cash_collect_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csv);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('CSV saved: ${file.path}')),
    );
  }

  Future<void> _exportPDF() async {
    if (_rows.isEmpty) return;
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Cash Collect (Per-Day)',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                cellAlignment: pw.Alignment.centerLeft,
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                headers: const ['Shop', 'Date', 'Cash', 'Collected'],
                data: _rows
                    .map((r) => [
                          r.shopName,
                          DateFormat('dd MMM, yyyy').format(r.day),
                          '\$ ${r.cash.toStringAsFixed(2)}',
                          r.collected ? 'Yes' : 'No',
                        ])
                    .toList(),
              ),
            ],
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  // ================== UI ==================
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();

    final shops = (app.shops as List? ?? const [])
        .where((e) => (e['isDeleted'] ?? false) != true)
        .map((e) => (e['name'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    if (_rows.isEmpty &&
        (app.sales as List? ?? const []).isNotEmpty &&
        (app.shops as List? ?? const []).isNotEmpty) {
      Future.microtask(_rebuild);
    }

    final periodLabel = _periodLabel();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash Collect'),
        actions: [
          IconButton(
            tooltip: 'Export PDF',
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _rows.isEmpty ? null : _exportPDF,
          ),
          IconButton(
            tooltip: 'Export CSV',
            icon: const Icon(Icons.table_rows),
            onPressed: _rows.isEmpty ? null : _exportCSV,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _rebuild,
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              child: Column(
                children: [
                  // ===== Filters with stable alignment =====
                  LayoutBuilder(builder: (ctx, cs) {
                    final wide = cs.maxWidth >= 680;
                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 220,
                            child: _FilterDropdown(
                              label: 'Shop',
                              value: _shopFilter,
                              items: ['All', ...shops],
                              onChanged: (v) {
                                setState(() => _shopFilter = v ?? 'All');
                                _rebuild();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 220,
                            child: _FilterDropdown(
                              label: 'Period',
                              value: _period.nameLabel,
                              items: _Period.values.map((e) => e.nameLabel).toList(),
                              onChanged: (v) async {
                                final p = _PeriodUi.fromLabel(v ?? _Period.daily.nameLabel);
                                setState(() {
                                  _period = p;
                                  // back to today when Daily
                                  if (_period == _Period.daily) {
                                    final n = DateTime.now();
                                    _anchor = DateTime(n.year, n.month, n.day);
                                  }
                                  if (_period == _Period.monthly) {
                                    final n = DateTime.now();
                                    _anchor = DateTime(n.year, n.month, 1);
                                  } else if (_period == _Period.yearly) {
                                    final n = DateTime.now();
                                    _anchor = DateTime(n.year, 1, 1);
                                  }
                                  if (_period != _Period.range) _range = null;
                                });
                                if (!mounted) return;
                                if (_period == _Period.specific) {
                                  await _pickAnchorDate();
                                } else if (_period == _Period.range) {
                                  await _pickRange();
                                }
                                _rebuild();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomLeft,
                              child: _PeriodControls(
                                text: 'Period: $periodLabel',
                                isRange: _period == _Period.range,
                                loading: _loading,
                                onPrev: _navBusy ? null : () => _shift(-1),
                                onNext: _navBusy ? null : () => _shift(1),
                                onTapLabel: () async {
                                  if (_period == _Period.range) {
                                    await _pickRange();
                                  } else {
                                    await _pickAnchorDate();
                                  }
                                  if (!mounted) return;
                                  _rebuild();
                                },
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    // narrow -> stacked nicely
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FilterDropdown(
                          label: 'Shop',
                          value: _shopFilter,
                          items: ['All', ...shops],
                          onChanged: (v) {
                            setState(() => _shopFilter = v ?? 'All');
                            _rebuild();
                          },
                        ),
                        const SizedBox(height: 8),
                        _FilterDropdown(
                          label: 'Period',
                          value: _period.nameLabel,
                          items: _Period.values.map((e) => e.nameLabel).toList(),
                          onChanged: (v) async {
                            final p = _PeriodUi.fromLabel(v ?? _Period.daily.nameLabel);
                            setState(() {
                              _period = p;
                              if (_period == _Period.daily) {
                                final n = DateTime.now();
                                _anchor = DateTime(n.year, n.month, n.day);
                              }
                              if (_period == _Period.monthly) {
                                final n = DateTime.now();
                                _anchor = DateTime(n.year, n.month, 1);
                              } else if (_period == _Period.yearly) {
                                final n = DateTime.now();
                                _anchor = DateTime(n.year, 1, 1);
                              }
                              if (_period != _Period.range) _range = null;
                            });
                            if (!mounted) return;
                            if (_period == _Period.specific) {
                              await _pickAnchorDate();
                            } else if (_period == _Period.range) {
                              await _pickRange();
                            }
                            _rebuild();
                          },
                        ),
                        const SizedBox(height: 8),
                        _PeriodControls(
                          text: 'Period: $periodLabel',
                          isRange: _period == _Period.range,
                          loading: _loading,
                          onPrev: _navBusy ? null : () => _shift(-1),
                          onNext: _navBusy ? null : () => _shift(1),
                          onTapLabel: () async {
                            if (_period == _Period.range) {
                              await _pickRange();
                            } else {
                              await _pickAnchorDate();
                            }
                            if (!mounted) return;
                            _rebuild();
                          },
                        ),
                      ],
                    );
                  }),

                  const SizedBox(height: 8),
                  _totalsBar(),
                  const SizedBox(height: 8),

                  Expanded(
                    child: Column(
                      children: [
                        SizedBox(height: _kHeaderHeight, child: _HeaderRow()),
                        const SizedBox(height: _kGapBelowHeader),
                        Expanded(
                          child: _rows.isEmpty && !_loading
                              ? Center(
                                  child: Text(
                                    'No rows for selected period.',
                                    style: TextStyle(color: Colors.white.withOpacity(0.75)),
                                  ),
                                )
                              : Scrollbar(
                                  child: ListView.separated(
                                    itemCount: _rows.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                                    itemBuilder: (ctx, i) {
                                      final r = _rows[i];
                                      return _DataRow(
                                        data: r,
                                        onCollect: r.collected || _loading
                                            ? null
                                            : () async {
                                                await _setCollected(r, true);
                                                if (!mounted) return;
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: const Text('Marked Collected'),
                                                    action: SnackBarAction(
                                                      label: 'UNDO',
                                                      onPressed: () => _setCollected(r, false),
                                                    ),
                                                  ),
                                                );
                                              },
                                      );
                                    },
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (_loading)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        ),
      ),
    );
  }

  // ---- Pickers ----
  Future<void> _pickAnchorDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchor,
      firstDate: DateTime(2022, 1, 1),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked != null) setState(() => _anchor = picked);
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
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked != null) setState(() => _range = picked);
  }

  // ---- Arrows (prev/next) ----
  Future<void> _shift(int dir) async {
    if (_navBusy) return;
    setState(() => _navBusy = true);

    switch (_period) {
      case _Period.daily:
      case _Period.specific:
        _anchor = _anchor.add(Duration(days: dir));
        break;
      case _Period.weekly:
        _anchor = _anchor.add(Duration(days: 7 * dir));
        break;
      case _Period.monthly:
        _anchor = DateTime(_anchor.year, _anchor.month + dir, 1);
        break;
      case _Period.yearly:
        _anchor = DateTime(_anchor.year + dir, 1, 1);
        break;
      case _Period.range:
        if (_range != null) {
          final len = _range!.end.difference(_range!.start).inDays + 1;
          final s = _range!.start.add(Duration(days: len * dir));
          final e = _range!.end.add(Duration(days: len * dir));
          final today = DateTime.now();
          final cap = DateTime(today.year, today.month, today.day);
          final newEnd = e.isAfter(cap) ? cap : e;
          final delta = e.difference(newEnd).inDays;
          final newStart = s.subtract(Duration(days: delta));
          _range = DateTimeRange(start: newStart, end: newEnd);
        }
        break;
    }

    final today = DateTime.now();
    final t = DateTime(today.year, today.month, today.day);
    if (_anchor.isAfter(t)) _anchor = t;

    await _rebuild();
    if (!mounted) return;
    setState(() => _navBusy = false);
  }

  // ===== Bounds from anchor/range =====
  (DateTime, DateTime) _periodBounds() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_period == _Period.range && _range != null) {
      final s = DateTime(_range!.start.year, _range!.start.month, _range!.start.day);
      var e = DateTime(_range!.end.year, _range!.end.month, _range!.end.day);
      if (e.isAfter(today)) e = today;
      return (s, e);
    }

    switch (_period) {
      case _Period.daily:
      case _Period.specific: {
        final d = DateTime(_anchor.year, _anchor.month, _anchor.day);
        final capped = d.isAfter(today) ? today : d;
        return (capped, capped);
      }
      case _Period.weekly: {
        final end = _capToToday(_anchor, today);
        final start = end.subtract(const Duration(days: 6));
        return (start, end);
      }
      case _Period.monthly: {
        final a = _capToToday(_anchor, today);
        final first = DateTime(a.year, a.month, 1);
        final lastOfMonth = DateTime(a.year, a.month + 1, 0);
        final end = lastOfMonth.isAfter(today) ? today : lastOfMonth;
        return (first, end);
      }
      case _Period.yearly: {
        final a = _capToToday(_anchor, today);
        final first = DateTime(a.year, 1, 1);
        final last = DateTime(a.year, 12, 31);
        final end = last.isAfter(today) ? today : last;
        return (first, end);
      }
      case _Period.range:
        final d = DateTime(_anchor.year, _anchor.month, _anchor.day);
        return (d, d);
    }
  }

  DateTime _capToToday(DateTime d, DateTime today) {
    final dd = DateTime(d.year, d.month, d.day);
    return dd.isAfter(today) ? today : dd;
  }

  String _periodLabel() {
    if (_period == _Period.range && _range != null) {
      final s = _df.format(DateTime(_range!.start.year, _range!.start.month, _range!.start.day));
      final e = _df.format(DateTime(_range!.end.year, _range!.end.month, _range!.end.day));
      return '$s — $e';
    }
    final (from, to) = _periodBounds();
    if (_Period.daily == _period || _Period.specific == _period) {
      return _df.format(from);
    }
    return '${_df.format(from)} — ${_df.format(to)}';
  }
}

// ========= helpers / models =========
class _SaleAgg {
  bool hasSale = false;
  double cash = 0, card = 0, other = 0, total = 0;
}

enum _Period { daily, weekly, monthly, yearly, specific, range }

extension _PeriodUi on _Period {
  String get nameLabel {
    switch (this) {
      case _Period.daily:
        return 'Daily';
      case _Period.weekly:
        return 'Weekly';
      case _Period.monthly:
        return 'Monthly';
      case _Period.yearly:
        return 'Yearly';
      case _Period.specific:
        return 'Specific Date';
      case _Period.range:
        return 'Date Range';
    }
  }

  static _Period fromLabel(String label) {
    switch (label) {
      case 'Daily':
        return _Period.daily;
      case 'Weekly':
        return _Period.weekly;
      case 'Monthly':
        return _Period.monthly;
      case 'Yearly':
        return _Period.yearly;
      case 'Specific Date':
        return _Period.specific;
      case 'Date Range':
        return _Period.range;
      default:
        return _Period.daily;
    }
  }
}

class _RowVM {
  final String shopId;
  final String shopName;
  final DateTime day;
  final num cash;
  final bool hasSale;
  bool collected;

  _RowVM({
    required this.shopId,
    required this.shopName,
    required this.day,
    required this.cash,
    required this.hasSale,
    required this.collected,
  });
}

class _HeaderRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _mutedFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _mutedStroke),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: const Row(
        children: [
          Expanded(flex: 50, child: _HeadText('Shop')),
          Expanded(flex: 22, child: _HeadText('Cash')),
          Expanded(flex: 16, child: _HeadText('Status')),
          Expanded(flex: 12, child: _HeadText('Action')),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final _RowVM data;
  final VoidCallback? onCollect;

  const _DataRow({
    required this.data,
    this.onCollect,
  });

  @override
  Widget build(BuildContext context) {
    final actionsDisabled = data.collected;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 50,
            child: Text(
              '${data.shopName} • ${DateFormat('MM/dd').format(data.day)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 22,
            child: Text(
              '\$ ${data.cash.toStringAsFixed(2)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _neon, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 16,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _StatusIcon(collected: data.collected, hasSale: data.hasSale),
            ),
          ),
          Expanded(
            flex: 12,
            child: Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: data.collected ? 'Already collected' : 'Mark Collected',
                icon: Icon(
                  Icons.check_circle_rounded,
                  size: 22,
                  color: data.collected
                      ? Colors.greenAccent.withOpacity(0.45)
                      : Colors.greenAccent,
                ),
                onPressed: actionsDisabled ? null : onCollect,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final bool collected;
  final bool hasSale;
  const _StatusIcon({required this.collected, required this.hasSale});

  @override
  Widget build(BuildContext context) {
    if (collected) {
      return const Icon(Icons.check_circle, size: 18, color: Colors.greenAccent);
    }
    return Icon(
      Icons.close_rounded,
      size: 18,
      color: hasSale ? _danger : Colors.white70,
      semanticLabel: hasSale ? 'Not collected' : 'No sale',
    );
  }
}

class _HeadText extends StatelessWidget {
  final String text;
  const _HeadText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      const SizedBox(height: 3),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: _mutedFill,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _mutedStroke),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            icon: const Icon(Icons.expand_more, color: Colors.white70, size: 18),
            dropdownColor: const Color(0xFF121212),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            onChanged: onChanged,
            items: items
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
          ),
        ),
      ),
    ]);
  }
}

class _PeriodControls extends StatelessWidget {
  final String text;
  final bool isRange;
  final bool loading;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback? onTapLabel;

  const _PeriodControls({
    required this.text,
    required this.isRange,
    required this.loading,
    this.onPrev,
    this.onNext,
    this.onTapLabel,
  });

  @override
  Widget build(BuildContext context) {
    final icon = isRange ? Icons.date_range : Icons.event;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: _mutedFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _mutedStroke),
      ),
      child:Row(
  // center badge ko bachi hui width deni hai, isliye max rakho
  mainAxisSize: MainAxisSize.max,
  children: [
    IconButton(
      tooltip: 'Previous',
      icon: const Icon(Icons.chevron_left),
      onPressed: loading ? null : onPrev,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    ),

    // ⬇️ CENTER BADGE gets the remaining width
    Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: loading ? null : onTapLabel,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Icon(icon, color: Colors.tealAccent.shade400, size: 18),
              const SizedBox(width: 6),

              // ⬇️ text shrink with ellipsis (no overflow)
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),

              const SizedBox(width: 6),
              const Icon(Icons.edit_calendar_outlined, size: 16, color: Colors.white70),
            ],
          ),
        ),
      ),
    ),

    IconButton(
      tooltip: 'Next',
      icon: const Icon(Icons.chevron_right),
      onPressed: loading ? null : onNext,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    ),
  ],
)
    );
  }
}
