import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

class TransactionReportScreen extends StatefulWidget {
  final String shopName;
  const TransactionReportScreen({super.key, required this.shopName});

  @override
  State<TransactionReportScreen> createState() => _TransactionReportScreenState();
}

class _TransactionReportScreenState extends State<TransactionReportScreen> {
  DateTime _day = DateTime.now();

  String get _key => DateFormat('yyyy-MM-dd').format(_day);
  String get _pretty => DateFormat('MMM d, yyyy').format(_day);

  void _prev() => setState(() => _day = _day.subtract(const Duration(days: 1)));
  void _next() => setState(() => _day = _day.add(const Duration(days: 1)));

  bool get _isToday {
    final now = DateTime.now();
    final a = DateTime(_day.year, _day.month, _day.day);
    final b = DateTime(now.year, now.month, now.day);
    return a == b;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();

    // block employees from viewing (per your policy)
    if (app.isEmployee == true) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transactions')),
        body: const Center(child: Text('Not authorized')),
      );
    }

    // NOTE: This uses string dayKey "yyyy-MM-dd" — keep it if your data is like this.
    // If you store Timestamp dayKey, change to where('dayKey', isEqualTo: Timestamp.fromDate(...)).
    final q = FirebaseFirestore.instance
        .collection('transactions')
        .where('shopName', isEqualTo: widget.shopName)
        .where('dayKey', isEqualTo: _key)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: Text('Transactions · ${widget.shopName}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            IconButton(onPressed: _prev, icon: const Icon(Icons.chevron_left)),
            Text(_pretty, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            IconButton(onPressed: _isToday ? null : _next, icon: const Icon(Icons.chevron_right)),
            const Spacer(),
            FilledButton(
              onPressed: () async {
                // capture & guard context safely
                final ctx = context;
                final navigator = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(ctx);
                final appRead = ctx.read<AppDataProvider>();

                final totals = await appRead.computeDailyTransactionTotals(
                  widget.shopName,
                  _day,
                );

                if (!mounted) return;

                showDialog(
                  context: ctx,
                  builder: (dialogCtx) => AlertDialog(
                    title: const Text('Daily Summary'),
                    content: Text(
                      'Cash:  ₨${(totals['cash'] ?? 0).toStringAsFixed(2)}\n'
                      'Card:  ₨${(totals['card'] ?? 0).toStringAsFixed(2)}\n'
                      'Other: ₨${(totals['other'] ?? 0).toStringAsFixed(2)}\n'
                      '———————————————\n'
                      'Total: ₨${(totals['total'] ?? 0).toStringAsFixed(2)}',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        child: const Text('Close'),
                      ),
                      FilledButton(
                        onPressed: () async {
                          navigator.pop(); // close dialog
                          final res = await appRead.postDailySaleFromTransactions(
                            shopName: widget.shopName,
                            day: _day,
                          );
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(content: Text(res ?? 'Daily sale posted')),
                          );
                        },
                        child: const Text('Close Day & Post Sale'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Summary / Close Day'),
            )
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: q,
              builder: (c, s) {
                if (s.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = s.data?.docs ?? const [];
                if (docs.isEmpty) return const Center(child: Text('No transactions for this day'));

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final d = docs[i].data();
                    final t = (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                    final time = DateFormat('HH:mm:ss').format(t);
                    final method = (d['method'] ?? '').toString().toUpperCase();
                    final amt = (d['amount'] as num?)?.toDouble() ?? 0;
                    final refund = (d['isRefund'] == true) || (d['refund'] == true);
                    final isNeg = refund || amt < 0;
                    final absAmt = amt.abs();

                    Color chipBg() {
                      switch (method) {
                        case 'CASH': return Colors.green.withValues(alpha: 0.12);
                        case 'CARD': return Colors.blue.withValues(alpha: 0.12);
                        default: return Colors.grey.withValues(alpha: 0.12);
                      }
                    }

                    return ListTile(
                      leading: Text(time),
                      title: Text('${isNeg ? '-' : ''}₨${absAmt.toStringAsFixed(2)}'),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: chipBg(), borderRadius: BorderRadius.circular(24)),
                        child: Text(method),
                      ),
                      subtitle: refund ? const Text('Refund', style: TextStyle(color: Colors.red)) : null,
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
