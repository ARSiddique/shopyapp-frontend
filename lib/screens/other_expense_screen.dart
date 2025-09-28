import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

const double _kRowHeight = 56;

class OtherExpenseScreen extends StatefulWidget {
  const OtherExpenseScreen({super.key});

  @override
  State<OtherExpenseScreen> createState() => _OtherExpenseScreenState();
}

class _OtherExpenseScreenState extends State<OtherExpenseScreen> {
  DateTime _anchor = DateTime.now();
  bool _loading = true;
  List<Map<String, dynamic>> _items = const [];
  double _total = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final app = context.read<AppDataProvider>();
    final start = DateTime(_anchor.year, _anchor.month, 1);
    final end = DateTime(_anchor.year, _anchor.month + 1, 1);

    final list = await app.fetchOtherExpenses(
      from: start,
      to: end,
      shopName: null, // ← no shop filter
    );

    final sum = list.fold<double>(
      0.0,
      (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0.0),
    );

    if (!mounted) return;
    setState(() {
      _items = list;
      _total = sum;
      _loading = false;
    });
  }

  Future<void> _shiftMonth(int delta) async {
    setState(() {
      _anchor = DateTime(_anchor.year, _anchor.month + delta, 1);
    });
    await _load();
  }

  Future<void> _addExpenseDialog() async {
    final titleCtl = TextEditingController();
    final amountCtl = TextEditingController();
    DateTime picked = DateTime.now();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add other expense'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtl,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: amountCtl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Date:'),
                const SizedBox(width: 8),
                Text(DateFormat('yyyy-MM-dd').format(picked)),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: picked,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) {
                      picked = d;
                      if (mounted) setState(() {});
                    }
                  },
                  child: const Text('Pick'),
                )
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final title = titleCtl.text.trim();
              final amount = double.tryParse(amountCtl.text.trim()) ?? 0.0;
              if (title.isEmpty || amount <= 0) return;

              await context.read<AppDataProvider>().addOtherExpenseEntry(
                    shopName: '', // not used
                    amount: amount,
                    title: title,
                    when: picked,
                  );
              if (!mounted) return;
              Navigator.pop(context);
              await _load();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthStr = DateFormat('MMMM yyyy').format(_anchor);

    return Scaffold(
      appBar: AppBar(title: const Text('Other Expense')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addExpenseDialog,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      // full-width bottom total
      bottomNavigationBar: SafeArea(child: _totalTile(_total)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => _shiftMonth(-1),
                  ),
                  Expanded(
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(monthStr,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => _shiftMonth(1),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _items.isEmpty
                        ? const Center(child: Text('No expenses this month'))
                        : ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final m = _items[i];
                              final title = (m['title'] ?? '').toString();
                              final amount =
                                  (m['amount'] as num?)?.toDouble() ?? 0.0;
                              return Container(
                                height: _kRowHeight,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.green),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(title)),
                                    Text('\$${amount.toStringAsFixed(2)}'),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _totalTile(double total) {
    return Container(
      width: double.infinity,
      height: _kRowHeight, // same height as list rows
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text('Total Expense',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Text('\$${total.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
