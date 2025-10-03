import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

class EmployeeExpenseBreakdownScreen extends StatefulWidget {
  const EmployeeExpenseBreakdownScreen({super.key, required this.month});
  final DateTime month;

  @override
  State<EmployeeExpenseBreakdownScreen> createState() => _EmployeeExpenseBreakdownScreenState();
}

class _EmployeeExpenseBreakdownScreenState extends State<EmployeeExpenseBreakdownScreen> {
  bool _loading = true;
  List<MapEntry<String, double>> _rows = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  (DateTime, DateTime) _bounds(DateTime m) =>
      (DateTime(m.year, m.month, 1), DateTime(m.year, m.month + 1, 1));

  Future<void> _load() async {
    setState(() => _loading = true);
    final app = context.read<AppDataProvider>();
    final (from, toExcl) = _bounds(widget.month);
    final list = await app.fetchEmployeeExpenses(from: from, to: toExcl, shopName: null);

    final Map<String, double> sumByEmp = {};
    for (final e in list) {
      final name = (e['employeeName'] ?? '—').toString();
      final amt = (e['amount'] is num) ? (e['amount'] as num).toDouble() : double.tryParse('${e['amount']}') ?? 0.0;
      sumByEmp[name] = (sumByEmp[name] ?? 0) + amt;
    }

    final rows = sumByEmp.entries
        .where((kv) => kv.value > 0) // sirf jinka expense > 0
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = 'Employee expense • ${DateFormat('MMMM yyyy').format(widget.month)}';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? const Center(child: Text('No employee expenses this month'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final e = _rows[i];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(e.key)),
                          Text('\$${e.value.toStringAsFixed(2)}'),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
