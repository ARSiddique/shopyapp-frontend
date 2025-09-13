// lib/screens/transaction_report_screen.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/app_data_provider.dart';

class TransactionReportScreen extends StatefulWidget {
  final String shopName;
  const TransactionReportScreen({super.key, required this.shopName});

  @override
  State<TransactionReportScreen> createState() => _TransactionReportScreenState();
}

class _TransactionReportScreenState extends State<TransactionReportScreen> {
  DateTime _day = DateTime.now();

  // cache for export
  List<_TxRow> _lastRows = [];
  String _lastHeader = '';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();
    final key = app.dayKeyOf(_day);

    return Scaffold(
      appBar: AppBar(
        title: Text('Transactions · ${widget.shopName}'),
        actions: [
          IconButton(
            tooltip: 'Export PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _exportPdf,
          ),
          IconButton(
            tooltip: 'Export CSV',
            icon: const Icon(Icons.table_chart_outlined),
            onPressed: _exportCsv,
          ),
        ],
      ),
      body: Column(
        children: [
          _dateHeader(app),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              // no orderBy → no composite index requirement
              stream: FirebaseFirestore.instance
                  .collection('transactions')
                  .where('shopName', isEqualTo: widget.shopName)
                  .where('dayKey', isEqualTo: key)
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }

                final docs = (snap.data?.docs ?? []).toList();

                // client-side sort by createdAt desc
                docs.sort((a, b) {
                  DateTime da = _toDate(a.data()['createdAt']);
                  DateTime db = _toDate(b.data()['createdAt']);
                  return db.compareTo(da);
                });

                final rows = docs.map(_mapDoc).toList();

                // cache for export
                _lastRows = rows;
                _lastHeader = '${widget.shopName} • ${DateFormat('dd MMM, yyyy').format(_day)}';

                if (rows.isEmpty) {
                  return const Center(child: Text('No transactions for this day'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final r = rows[i];
                    final method = r.method == 'cash'
                        ? 'Cash'
                        : r.method == 'card'
                            ? 'Card'
                            : 'Other';
                    final when = DateFormat('hh:mm a').format(r.createdAt);
                    final sign = r.isRefund ? '-' : '+';

                    return Card(
                      child: ListTile(
                        dense: true,
                        title: Text(
                          'Rs ${r.amountAbs.toStringAsFixed(2)}  $sign',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: r.isRefund ? Colors.red : null,
                          ),
                        ),
                        subtitle: Text('$method  •  $when  •  ${r.createdBy ?? '-'}'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Header with date nav + CLOSED badge + Close Day button ----------
Widget _dateHeader(AppDataProvider app) {
  final label = DateFormat('MMM d, yyyy').format(_day);

  return Padding(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
    child: LayoutBuilder(
      builder: (ctx, cons) {
        final tiny = cons.maxWidth < 360; // very small phones

        return Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() => _day = _day.subtract(const Duration(days: 1))),
            ),

            // Center label always gets to flex and can ellipsize
            Expanded(
              child: FutureBuilder<bool>(
                future: app.isDayClosed(widget.shopName, _day),
                builder: (ctx, s) {
                  final closed = s.data == true;
                  return Text(
                    closed ? '$label — CLOSED' : label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  );
                },
              ),
            ),

            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() => _day = _day.add(const Duration(days: 1))),
            ),

            const SizedBox(width: 6),

            // Close-day action shrinks instead of overflowing
            FutureBuilder<bool>(
              future: app.isDayClosed(widget.shopName, _day),
              builder: (ctx, s) {
                final closed = s.data == true;

                final button = TextButton.icon(
                  icon: const Icon(Icons.summarize_outlined, size: 18),
                  label: Text(closed ? 'Day Closed' : 'Summary / Close Day'),
                  onPressed: closed ? null : () => _openCloseDaySheet(app),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    minimumSize: const Size(0, 36),
                  ),
                );

                // On tiny screens, show icon-only to save space
                if (tiny) {
                  return IconButton(
                    tooltip: closed ? 'Day Closed' : 'Summary / Close Day',
                    icon: const Icon(Icons.summarize_outlined),
                    onPressed: closed ? null : () => _openCloseDaySheet(app),
                  );
                }

                // Otherwise scale down if needed (prevents overflow)
                return FittedBox(
                  fit: BoxFit.scaleDown,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 170),
                    child: button,
                  ),
                );
              },
            ),
          ],
        );
      },
    ),
  );
}

  // ---------- Summary & Close sheet ----------
  Future<void> _openCloseDaySheet(AppDataProvider app) async {
    final totals = await app.computeDailyTransactionTotals(widget.shopName, _day);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Summary • ${DateFormat('dd MMM, yyyy').format(_day)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _kv('Cash',  'Rs ${(totals['cash'] ?? 0).toStringAsFixed(0)}'),
            _kv('Card',  'Rs ${(totals['card'] ?? 0).toStringAsFixed(0)}'),
            _kv('Other', 'Rs ${(totals['other'] ?? 0).toStringAsFixed(0)}'),
            const Divider(),
            _kv('Total', 'Rs ${(totals['total'] ?? 0).toStringAsFixed(0)}'),
            const SizedBox(height: 12),
            Row(
              children: [
                const Spacer(),
                FilledButton.icon(
                  icon: const Icon(Icons.publish_outlined),
                  label: const Text('Close Day (Post Sale)'),
                  onPressed: () async {
                    final err = await app.postDailySaleFromTransactions(
                      shopName: widget.shopName,
                      day: _day,
                    );
                    if (!mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(err ?? 'Daily Sale posted')),
                    );
                    setState(() {}); // refresh badge
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Exports ----------
  Future<void> _exportCsv() async {
    if (_lastRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to export')),
      );
      return;
    }

    final b = StringBuffer();
    b.writeln('Shop,Date,Time,Method,Amount,Type,By');

    for (final r in _lastRows) {
      b.writeln([
        _csvEsc(widget.shopName),
        DateFormat('yyyy-MM-dd').format(_day),
        DateFormat('HH:mm:ss').format(r.createdAt),
        r.method,
        r.amountAbs.toStringAsFixed(2),
        r.isRefund ? 'refund' : 'sale',
        _csvEsc(r.createdBy ?? ''),
      ].join(','));
    }

    final dir = await getTemporaryDirectory();
    final name = 'transactions_${widget.shopName}_${DateFormat('yyyyMMdd').format(_day)}.csv';
    final file = File('${dir.path}/$name');
    await file.writeAsString(b.toString(), flush: true);

    await Share.shareXFiles([XFile(file.path)], text: _lastHeader);
  }

  Future<void> _exportPdf() async {
    if (_lastRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to export')),
      );
      return;
    }

    final pdf = pw.Document();
    final dateText = DateFormat('dd MMM, yyyy').format(_day);

    pdf.addPage(
      pw.MultiPage(
        build: (ctx) => [
          pw.Text('Transaction Report',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Shop: ${widget.shopName}'),
          pw.Text('Date: $dateText'),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: const ['Time', 'Method', 'Type', 'Amount', 'By'],
            data: _lastRows.map((r) {
              return [
                DateFormat('HH:mm:ss').format(r.createdAt),
                r.method,
                r.isRefund ? 'refund' : 'sale',
                r.amountAbs.toStringAsFixed(2),
                r.createdBy ?? '',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    final name =
        'transactions_${widget.shopName}_${DateFormat('yyyyMMdd').format(_day)}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: name);
  }

  // ---------- helpers ----------
  static DateTime _toDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
    return DateTime.now();
  }

  static String _csvEsc(String s) {
    final needs = s.contains(',') || s.contains('\n') || s.contains('"');
    if (!needs) return s;
    return '"${s.replaceAll('"', '""')}"';
  }

  _TxRow _mapDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    final createdAt = _toDate(m['createdAt']);
    final amount = (m['amount'] as num?)?.toDouble() ?? 0.0;
    final refund = (m['isRefund'] ?? false) == true;

    return _TxRow(
      createdAt: createdAt,
      amountAbs: amount.abs(),
      isRefund: refund || amount.isNegative,
      method: (m['method'] ?? '').toString(), // 'cash'|'card'|'other'
      createdBy: (m['createdByName'] ?? m['createdBy'] ?? '').toString(),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [Expanded(child: Text(k)), Text(v)]),
      );
}

class _TxRow {
  final DateTime createdAt;
  final double amountAbs;
  final bool isRefund;
  final String method;
  final String? createdBy;

  _TxRow({
    required this.createdAt,
    required this.amountAbs,
    required this.isRefund,
    required this.method,
    required this.createdBy,
  });
}
