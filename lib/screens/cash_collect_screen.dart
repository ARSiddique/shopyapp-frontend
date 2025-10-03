// lib/screens/cash_collect_screen.dart
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:csv/csv.dart';

import '../providers/app_data_provider.dart';

const _neon = Color(0xFF00FFC6);
const _danger = Color(0xFFFF6B6B);
const _mutedStroke = Color(0x22FFFFFF);
const _mutedFill = Color(0x12FFFFFF);

class CashCollectScreen extends StatefulWidget {
  const CashCollectScreen({super.key});

  @override
  State<CashCollectScreen> createState() => _CashCollectScreenState();
}

class _CashCollectScreenState extends State<CashCollectScreen> {
  final _df = DateFormat('dd MMM, yyyy');

  String _shopFilter = 'All';
  _Period _period = _Period.daily;
  DateTime _anchor = DateTime.now();

  List<_RowVM> _rows = const [];
  AppDataProvider? _appSub;

  static const double _kHeaderHeight = 34;
  static const double _kGapBelowHeader = 4;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final app = context.read<AppDataProvider>();
      // ensure sales loaded for computeCashForShop()
      if ((app.sales as List?)?.isEmpty ?? true) {
        await app.fetchSales();
      }
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

  Future<void> _rebuild() async {
    final app = context.read<AppDataProvider>();
    final rows = await _buildRows(app);
    if (!mounted) return;
    setState(() => _rows = rows);
  }

  // ===== NEW: Totals (Total / Picked / Not Picked) =====
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

  // ---- Exports ----
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
            onPressed: _rebuild,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          child: Column(
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
              const SizedBox(height: 6),
              _FilterDropdown(
                label: 'Period',
                value: _period.nameLabel,
                items: _Period.values.map((e) => e.nameLabel).toList(),
                onChanged: (v) {
                  final p = _PeriodUi.fromLabel(v ?? _Period.daily.nameLabel);
                  setState(() => _period = p);
                  _rebuild();
                },
              ),
              const SizedBox(height: 6),
              _PeriodBadge(
                icon: Icons.event,
                text: 'Period: $periodLabel',
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2022),
                    lastDate: DateTime.now(),
                    initialDate: _anchor,
                  );
                  if (!mounted) return;
                  if (picked != null) {
                    setState(() => _anchor = picked);
                    _rebuild();
                  }
                },
              ),

              const SizedBox(height: 8),
              // ===== NEW: Totals Bar =====
              _totalsBar(),
              const SizedBox(height: 8),

              // Table
              Expanded(
                child: Column(
                  children: [
                    SizedBox(height: _kHeaderHeight, child: _HeaderRow()),
                    const SizedBox(height: _kGapBelowHeader),
                    Expanded(
                      child: _rows.isEmpty
                          ? Center(
                              child: Text(
                                'No rows for selected period.',
                                style: TextStyle(color: Colors.white.withOpacity(0.75)),
                              ),
                            )
                          : ListView.separated(
                              itemCount: _rows.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 4),
                              itemBuilder: (ctx, i) {
                                final r = _rows[i];
                                return _DataRow(
                                  data: r,
                                  onCollect: r.collected
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<_RowVM>> _buildRows(AppDataProvider app) async {
    final allShopNames = (app.shops as List? ?? const [])
        .where((e) => (e['isDeleted'] ?? false) != true)
        .map((e) => (e['name'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final List<String> shopNames = _shopFilter == 'All'
        ? allShopNames
        : allShopNames.where((s) => s.toLowerCase() == _shopFilter.toLowerCase()).toList();

    final (DateTime from, DateTime to) = _periodBounds();
    final days = <DateTime>[];
    for (DateTime d = from;
        !d.isAfter(to);
        d = DateTime(d.year, d.month, d.day).add(const Duration(days: 1))) {
      days.add(DateTime(d.year, d.month, d.day));
    }

    final rows = <_RowVM>[];

    for (final day in days.reversed) {
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = dayStart;

      final items = await Future.wait(shopNames.map((_shopName) async {
        final shopId = app.shopIdForName(_shopName) ?? '';
        if (shopId.isEmpty) return null;

        final cash = app.computeCashForShop(shopId, dayStart, dayEnd);

        final hasSale = app.sales.any((s) {
          final sid = (s['shopId'] ?? s['shop'] ?? '').toString().trim();
          if (sid != shopId) return false;
          final saleDateStr = (s['saleDate'] ?? '').toString();
          if (saleDateStr.length < 10) return false;
          try {
            final p = saleDateStr.split('-');
            final sd = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
            return sd.year == dayStart.year && sd.month == dayStart.month && sd.day == dayStart.day;
          } catch (_) {
            return false;
          }
        });

        bool collected = false;
        try {
          collected = await app.isCashCollected(shopId: shopId, from: dayStart, to: dayEnd);
        } catch (_) {}

        return _RowVM(
          shopId: shopId,
          shopName: _shopName,
          day: dayStart,
          cash: cash,
          hasSale: hasSale,
          collected: collected,
        );
      }));

      rows.addAll(items.whereType<_RowVM>());
    }

    rows.sort((a, b) {
      final c = b.day.compareTo(a.day);
      if (c != 0) return c;
      return a.shopName.compareTo(b.shopName);
    });

    return rows;
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
  }

  (DateTime, DateTime) _periodBounds() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_period) {
      case _Period.daily:
        final d = DateTime(_anchor.year, _anchor.month, _anchor.day);
        final capped = d.isAfter(today) ? today : d;
        return (capped, capped);
      case _Period.weekly:
        final start = today.subtract(const Duration(days: 6));
        return (start, today);
      case _Period.monthly:
        final start = today.subtract(const Duration(days: 30));
        return (start, today);
      case _Period.yearly:
        final start = today.subtract(const Duration(days: 365));
        return (start, today);
      case _Period.specific:
        final d = DateTime(_anchor.year, _anchor.month, _anchor.day);
        final capped = d.isAfter(today) ? today : d;
        return (capped, capped);
      case _Period.range:
        final s = DateTime(_anchor.year, _anchor.month, _anchor.day).subtract(const Duration(days: 3));
        var e = DateTime(_anchor.year, _anchor.month, _anchor.day).add(const Duration(days: 3));
        if (e.isAfter(today)) e = today;
        return (s.isAfter(e) ? e : s, e);
    }
  }

  String _periodLabel() {
    final (from, to) = _periodBounds();
    if (_Period.daily == _period || _Period.specific == _period) {
      return _df.format(from);
    }
    return '${_df.format(from)} — ${_df.format(to)}';
  }
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

class _PeriodBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;
  const _PeriodBadge({required this.icon, required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: _mutedFill,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _mutedStroke),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.tealAccent.shade400, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.edit_calendar_outlined, size: 16, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}
