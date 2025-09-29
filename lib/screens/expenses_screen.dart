import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';
import 'add_expense_screen.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final bool _busy = false;
  final _df = DateFormat('dd MMM, hh:mm a');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppDataProvider>().fetchExpenses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();
    final me = app.loggedInUser ?? {};
    final role = (me['role'] ?? 'employee').toString().toLowerCase();
    final isEmployee = role == 'employee';
    final myShops = ((me['assignedShops'] ?? []) as List).map((e) => e.toString()).toSet();

    final all = app.expenses;
    final rows = isEmployee
        ? all.where((e) => myShops.contains((e['shopName'] ?? '').toString())).toList()
        : all;

    final total = rows.fold<double>(0, (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => app.fetchExpenses(),
        child: rows.isEmpty
            ? ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 120),
                children: [
                  const Center(child: Text('No expenses found')),
                  const SizedBox(height: 12),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const AddExpenseScreen()));
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Expense'),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: rows.length + 1,
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return _TotalsBar(total: total);
                  }
                  final e = rows[i - 1];
                  final shop = (e['shopName'] ?? '').toString();
                  final cat = (e['category'] ?? 'Misc').toString();
                  final amt = (e['amount'] as num?)?.toDouble() ?? 0;
                  final createdAt = e['createdAt'];
                  final dt = createdAt is DateTime ? createdAt : DateTime.now();
                  final note = (e['note'] ?? '').toString();
                  final by = (e['createdBy'] ?? '').toString();

                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      title: Text('$shop  •  $cat', maxLines: 1, overflow: TextOverflow.ellipsis),
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
        onPressed: _busy ? null : () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AddExpenseScreen()));
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
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Row(
        children: [
          const Icon(Icons.summarize),
          const SizedBox(width: 8),
          const Text('Total Expenses: ', style: TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(total.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
