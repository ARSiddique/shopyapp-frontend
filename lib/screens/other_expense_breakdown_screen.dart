import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

class OtherExpenseBreakdownScreen extends StatefulWidget {
  const OtherExpenseBreakdownScreen({super.key, required this.month});
  final DateTime month;

  @override
  State<OtherExpenseBreakdownScreen> createState() => _OtherExpenseBreakdownScreenState();
}

class _OtherExpenseBreakdownScreenState extends State<OtherExpenseBreakdownScreen> {
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
    final list = await app.fetchOtherExpenses(from: from, to: toExcl, shopName: null);

    final Map<String, double> sumByCat = {};
    for (final e in list) {
      final cat = (e['title'] ?? e['category'] ?? 'Expense').toString();
      final amt = (e['amount'] is num) ? (e['amount'] as num).toDouble() : double.tryParse('${e['amount']}') ?? 0.0;
      sumByCat[cat] = (sumByCat[cat] ?? 0) + amt;
    }

    final rows = sumByCat.entries
        .where((kv) => kv.value > 0)
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
    final title = 'Other expense • ${DateFormat('MMMM yyyy').format(widget.month)}';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? const Center(child: Text('No other expenses this month'))
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
