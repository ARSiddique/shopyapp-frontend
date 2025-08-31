import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';
import 'add_payment_screen.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final _df = DateFormat('dd MMM, hh:mm a');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppDataProvider>().fetchPayments();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();
    final me = app.loggedInUser ?? {};
    final role = (me['role'] ?? 'employee').toString().toLowerCase();
    final isEmployee = role == 'employee';
    final myShops = ((me['assignedShops'] ?? []) as List).map((e) => e.toString()).toSet();

    final all = app.payments;
    final rows = isEmployee
        ? all.where((p) => myShops.contains((p['shopName'] ?? '').toString())).toList()
        : all;

    final total = rows.fold<double>(0, (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0));

    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      body: RefreshIndicator(
        onRefresh: () async => app.fetchPayments(),
        child: rows.isEmpty
            ? ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 120),
                children: [
                  const Center(child: Text('No payments found')),
                  const SizedBox(height: 12),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPaymentScreen()));
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Payment'),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: rows.length + 1,
                itemBuilder: (_, i) {
                  if (i == 0) return _TotalsBar(total: total);
                  final p = rows[i - 1];
                  final shop = (p['shopName'] ?? '').toString();
                  final toWh = (p['toWholesalerName'] ?? '').toString();
                  final amt = (p['amount'] as num?)?.toDouble() ?? 0;
                  final createdAt = p['createdAt'];
                  final dt = createdAt is DateTime ? createdAt : DateTime.now();
                  final note = (p['note'] ?? '').toString();
                  final by = (p['createdBy'] ?? '').toString();

                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      title: Text('$shop  •  $toWh', maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_df.format(dt)),
                          if (by.isNotEmpty) Text('By: $by'),
                          if (note.isNotEmpty) Text('Note: $note'),
                        ],
                      ),
                      trailing: Text(amt.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPaymentScreen()));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _TotalsBar extends StatelessWidget {
  const _TotalsBar({required this.total});
  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade100),
      ),
      child: Row(
        children: [
          const Icon(Icons.summarize),
          const SizedBox(width: 8),
          const Text('Total Payments: ', style: TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(total.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
