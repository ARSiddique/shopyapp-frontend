// lib/screens/cash_collect_screen.dart
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:csv/csv.dart';
import '../providers/app_data_provider.dart';

/// ====== Theme tokens (match your app) ======
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

  // cache of collected flags loaded from Firestore for current period
  final Map<String, bool> _collectedMap = {}; // key = docId (shop|periodKey)

  // Built rows for the current filters (so we can export & update)
  List<_RowVM> _rows = const [];

  // header visual constants
  static const double _kMinTableWidth = 780;
  static const double _kHeaderHeight = 52;
  static const double _kGapBelowHeader = 8;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rebuildAndWarmStatuses();
  }

  void _rebuildAndWarmStatuses() {
    final app = context.read<AppDataProvider>();
    final rows = _buildRows(app);
    setState(() => _rows = rows);
    _loadCollectedStatusesForRows(rows);
  }

  // ---- Firestore helpers for Collected status ----
  String _periodKey(DateTime from, DateTime to) =>
      '${from.millisecondsSinceEpoch}_${to.millisecondsSinceEpoch}';
  String _docIdFor(String shop, String periodKey) => '$shop|$periodKey';

  Future<void> _loadCollectedStatusesForRows(List<_RowVM> rows) async {
    if (rows.isEmpty) return;
    // Loop (kept simple & robust)
    for (final r in rows) {
      final docId = _docIdFor(r.shop, r.periodKey);
      try {
        final snap = await FirebaseFirestore.instance
            .collection('cash_collect')
            .doc(docId)
            .get();
        if (snap.exists && (snap.data()?['collected'] == true)) {
          _collectedMap[docId] = true;
        } else {
          _collectedMap[docId] = false;
        }
      } catch (_) {
        _collectedMap[docId] = false;
      }
    }
    // reflect into rows
    setState(() {
      for (final r in _rows) {
        final docId = _docIdFor(r.shop, r.periodKey);
        r.collected = _collectedMap[docId] ?? false;
        if (r.collected) {
          r.statusText = 'Collected';
          r.statusColor = Colors.greenAccent;
        }
      }
    });
  }

  Future<void> _setCollected(_RowVM row, bool collected) async {
    final (from, to) = _periodBounds(_anchor);
    final pk = _periodKey(from, to);
    final docId = _docIdFor(row.shop, pk);

    await FirebaseFirestore.instance.collection('cash_collect').doc(docId).set({
      'id': docId,
      'shopName': row.shop,
      'from': Timestamp.fromDate(from),
      'to': Timestamp.fromDate(to),
      'periodKey': pk,
      'collected': collected,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    setState(() {
      _collectedMap[docId] = collected;
      row.collected = collected;
      if (collected) {
        row.statusText = 'Collected';
        row.statusColor = Colors.greenAccent;
      } else {
        // restore status depending on whether sale exists
        if (row.hasSale) {
          row.statusText = 'Pending';
          row.statusColor = Colors.amberAccent;
        } else {
          row.statusText = 'Sale not submitted';
          row.statusColor = _danger;
        }
      }
    });
  }

  // ---- Exports ----
  Future<void> _exportCSV() async {
    if (_rows.isEmpty) return;
    final data = <List<dynamic>>[
      ['Shop', 'Period', 'Cash', 'Status'],
      ..._rows.map((r) => [r.shop, r.periodText, r.cash, r.statusText]),
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
              pw.Text('Cash Collect', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                cellAlignment: pw.Alignment.centerLeft,
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                headers: ['Shop', 'Period', 'Cash', 'Status'],
                data: _rows
                    .map((r) => [r.shop, r.periodText, 'Rs ${r.cash}', r.statusText])
                    .toList(),
              ),
            ],
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  // ---- UI ----
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();
    final shops = (app.shops as List? ?? const [])
        .map((e) => (e['name'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

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
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'refresh') _rebuildAndWarmStatuses();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'refresh', child: Text('Refresh')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            children: [
              // Filters
              _FilterDropdown(
                label: 'Shop',
                value: _shopFilter,
                items: ['All', ...shops],
                onChanged: (v) {
                  setState(() => _shopFilter = v ?? 'All');
                  _rebuildAndWarmStatuses();
                },
              ),
              const SizedBox(height: 10),
              _FilterDropdown(
                label: 'Period',
                value: _period.nameLabel,
                items: _Period.values.map((e) => e.nameLabel).toList(),
                onChanged: (v) {
                  final p = _PeriodUi.fromLabel(v ?? _Period.daily.nameLabel);
                  setState(() => _period = p);
                  _rebuildAndWarmStatuses();
                },
              ),
              const SizedBox(height: 10),
              _PeriodBadge(
                icon: Icons.event,
                text: 'Period: $periodLabel',
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2022),
                    lastDate: DateTime(2100),
                    initialDate: _anchor,
                  );
                  if (!mounted) return;
                  if (picked != null) {
                    setState(() => _anchor = picked);
                    _rebuildAndWarmStatuses();
                  }
                },
              ),
              const SizedBox(height: 12),

              // Table area (no Expanded inside a horizontal scroll)
              Expanded(
                child: LayoutBuilder(
                  builder: (ctx, cs) {
                    // compute heights for header + list
                    final listHeight =
                        max(0.0, cs.maxHeight - _kHeaderHeight - _kGapBelowHeader);

                    final tableContent = Column(
                      children: [
                        SizedBox(
                          height: _kHeaderHeight,
                          child: _HeaderRow(),
                        ),
                        const SizedBox(height: _kGapBelowHeader),
                        SizedBox(
                          height: listHeight,
                          child: _rows.isEmpty
                              ? Center(
                                  child: Text(
                                    'No shops for selected period.',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.75),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: _rows.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (ctx, i) {
                                    final r = _rows[i];
                                    return _DataRow(
                                      data: r,
                                      onCollect: r.collected
                                          ? null
                                          : () async {
                                              await _setCollected(r, true);
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content:
                                                      const Text('Marked Collected'),
                                                  action: SnackBarAction(
                                                    label: 'UNDO',
                                                    onPressed: () =>
                                                        _setCollected(r, false),
                                                  ),
                                                ),
                                              );
                                            },
                                      onNotCollected: r.collected
                                          ? null
                                          : () {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                      'Marked as Not Collected'),
                                                ),
                                              );
                                            },
                                    );
                                  },
                                ),
                        ),
                      ],
                    );

                    if (cs.maxWidth < _kMinTableWidth) {
                      return Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: _kMinTableWidth,
                            child: tableContent,
                          ),
                        ),
                      );
                    }
                    return tableContent;
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build per-shop rows by period window
  List<_RowVM> _buildRows(AppDataProvider app) {
    // shops list
    final allShops = (app.shops as List? ?? const [])
        .map((e) => (e['name'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final List<String> shops = _shopFilter == 'All'
        ? allShops
        : allShops
            .where((s) => s.toLowerCase() == _shopFilter.toLowerCase())
            .toList();

    final (DateTime from, DateTime to) = _periodBounds(_anchor);
    final pk = _periodKey(from, to);

    final sales = (app.sales as List? ?? const []).cast<Map>();

    final rows = <_RowVM>[];
    for (final shop in shops) {
      // filter sales by shop and date range
      final shopSales = sales.where((s) {
        final sShop = (s['shop'] ?? '').toString();
        if (!equalsIgnoreCase(sShop, shop)) return false;

        // saleDate expected "yyyy-MM-dd"
        final sdStr = (s['saleDate'] ?? '').toString();
        DateTime? sd;
        try {
          if (sdStr.contains('-')) {
            final parts = sdStr.split('-');
            sd = DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
            );
          }
        } catch (_) {}
        if (sd == null) return false;

        return !sd.isBefore(from) && !sd.isAfter(to);
      }).toList();

      // compute cash (sum) & hasSale
      num cash = 0;
      for (final s in shopSales) {
        final n = (s['cash'] ?? s['computedCash'] ?? 0);
        if (n is num) cash += n;
      }
      final hasSale = shopSales.isNotEmpty;

      // default status before collected check
      String status;
      Color statusColor;
      if (!hasSale) {
        status = 'Sale not submitted';
        statusColor = _danger;
      } else {
        status = 'Pending';
        statusColor = Colors.amberAccent;
      }

      rows.add(
        _RowVM(
          shop: shop,
          periodText: _periodLabel(),
          periodKey: pk,
          cash: cash,
          hasSale: hasSale,
          statusText: status,
          statusColor: statusColor,
          collected: false, // will be warmed by _loadCollectedStatusesForRows
        ),
      );
    }

    return rows;
  }

  (DateTime, DateTime) _periodBounds(DateTime anchor) {
    final d = DateTime(anchor.year, anchor.month, anchor.day);
    switch (_period) {
      case _Period.daily:
        return (d, d);
      case _Period.weekly:
        final start = d.subtract(Duration(days: d.weekday - 1));
        final end = start.add(const Duration(days: 6));
        return (start, end);
      case _Period.monthly:
        final start = DateTime(d.year, d.month, 1);
        final end = DateTime(d.year, d.month + 1, 0);
        return (start, end);
      case _Period.yearly:
        final start = DateTime(d.year, 1, 1);
        final end = DateTime(d.year, 12, 31);
        return (start, end);
      case _Period.specific:
        return (d, d);
      case _Period.range:
        // quick stub (replace with real picker if you add one)
        final start = d.subtract(const Duration(days: 3));
        final end = d.add(const Duration(days: 3));
        return (start, end);
    }
  }

  String _periodLabel() {
    final (from, to) = _periodBounds(_anchor);
    switch (_period) {
      case _Period.daily:
      case _Period.specific:
        return _df.format(from);
      case _Period.weekly:
      case _Period.monthly:
      case _Period.yearly:
      case _Period.range:
        return '${_df.format(from)} — ${_df.format(to)}';
    }
  }
}

/// ===== Helpers & small widgets =====
bool equalsIgnoreCase(String a, String b) => a.toLowerCase() == b.toLowerCase();

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

  // static-like helper lives on the extension
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
  final String shop;
  final String periodText;
  final String periodKey; // from_to
  final num cash;
  final bool hasSale;
  String statusText;
  Color statusColor;
  bool collected;

  _RowVM({
    required this.shop,
    required this.periodText,
    required this.periodKey,
    required this.cash,
    required this.hasSale,
    required this.statusText,
    required this.statusColor,
    required this.collected,
  });
}

class _HeaderRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _mutedFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _mutedStroke),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: const Row(
        children: [
          Expanded(flex: 28, child: _HeadText('Shop')),
          Expanded(flex: 26, child: _HeadText('Period')),
          Expanded(flex: 18, child: _HeadText('Cash')),
          Expanded(flex: 20, child: _HeadText('Status')),
          Expanded(flex: 18, child: _HeadText('Actions')),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final _RowVM data;
  final VoidCallback? onCollect;
  final VoidCallback? onNotCollected;

  const _DataRow({
    required this.data,
    this.onCollect,
    this.onNotCollected,
  });

  @override
  Widget build(BuildContext context) {
    final actionsDisabled = data.collected;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 28, child: Text(data.shop)),
          Expanded(flex: 26, child: Text(data.periodText)),
          Expanded(
            flex: 18,
            child: Text(
              'Rs ${data.cash}',
              style: const TextStyle(color: _neon, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 20,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _StatusPill(text: data.statusText, color: data.statusColor),
            ),
          ),
          Expanded(
            flex: 18,
            child: actionsDisabled
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(Icons.check_circle, color: Colors.greenAccent),
                  )
                : Wrap(
                    spacing: 8,
                    children: [
                      _SmallBtn(
                        label: 'Collect',
                        icon: Icons.check_rounded,
                        onTap: onCollect,
                      ),
                      _SmallBtn(
                        label: 'Not Collected',
                        icon: Icons.close_rounded,
                        onTap: onNotCollected,
                        muted: true,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _HeadText extends StatelessWidget {
  final String text;
  const _HeadText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.w700,
        ));
  }
}

class _StatusPill extends StatelessWidget {
  final String text;
  final Color color;
  const _StatusPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.65)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool muted;
  const _SmallBtn({
    required this.label,
    required this.icon,
    this.onTap,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final active = onTap != null;
    final border =
        muted ? Colors.white.withOpacity(0.25) : _neon.withOpacity(0.65);
    final textColor = active
        ? (muted ? Colors.white.withOpacity(0.85) : _neon)
        : Colors.white.withOpacity(0.45);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
          color: Colors.white.withOpacity(muted ? 0.03 : 0.06),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: textColor),
            const SizedBox(width: 6),
            Text(label,
                style:
                    TextStyle(fontWeight: FontWeight.w700, color: textColor)),
          ],
        ),
      ),
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
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _mutedFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _mutedStroke),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            icon: const Icon(Icons.expand_more, color: Colors.white70),
            dropdownColor: const Color(0xFF121212),
            style: const TextStyle(color: Colors.white),
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
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _mutedFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _mutedStroke),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.tealAccent.shade400, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.edit_calendar_outlined,
                size: 18, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}
