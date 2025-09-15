import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

class OtherExpenseScreen extends StatefulWidget {
  const OtherExpenseScreen({super.key});

  @override
  State<OtherExpenseScreen> createState() => _OtherExpenseScreenState();
}

class _OtherExpenseScreenState extends State<OtherExpenseScreen> {
  final _df = DateFormat('MMM d, yyyy', 'en_US');

  String _view = 'Monthly';
  DateTime _anchor = DateTime.now();
  String? _shopFilter;

  bool _loading = false;
  List<Map<String, dynamic>> _rows = [];

  (DateTime from, DateTime to) _range() {
    final a = DateTime(_anchor.year, _anchor.month, _anchor.day);
    switch (_view) {
      case 'Daily':
        return (a, a.add(const Duration(days: 1)));
      case 'Weekly':
        final start = a.subtract(Duration(days: a.weekday - 1)); // Monday
        return (start, start.add(const Duration(days: 7)));
      case 'Yearly':
        return (DateTime(a.year, 1, 1), DateTime(a.year + 1, 1, 1));
      case 'Monthly':
      default:
        return (DateTime(a.year, a.month, 1), DateTime(a.year, a.month + 1, 1));
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final app = context.read<AppDataProvider>();
    final (from, to) = _range();

    final list = await app.fetchOtherExpenses(
      from: from,
      to: to,
      shopName: _shopFilter,
    );

    if (!mounted) return;
    setState(() {
      _rows = list;
      _loading = false;
    });
  }

  String _fmt(num v) =>
      NumberFormat.currency(locale: 'en_US', symbol: r'$').format(v);

  Future<void> _addExpenseDialog() async {
    final app = context.read<AppDataProvider>();
    final shops = app.shops
        .map((s) => (s['name'] ?? s['shopName'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toList();

    String? shop = _shopFilter ?? (shops.isNotEmpty ? shops.first : null);
    final titleCtl = TextEditingController(text: 'Expense');
    final amountCtl = TextEditingController();
    final noteCtl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Other Expense'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: shop,
              items: shops
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => shop = v,
              decoration: const InputDecoration(labelText: 'Shop'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: titleCtl,
              decoration: const InputDecoration(labelText: 'Category / Title'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: amountCtl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: noteCtl,
              decoration:
                  const InputDecoration(labelText: 'Note (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );

    if (ok == true && shop != null) {
      final amt = double.tryParse(amountCtl.text.trim()) ?? 0;
      if (amt <= 0) return;

      // Provider already has addExpense()
      await app.addExpense(
        shopName: shop!,
        amount: amt,
        category: titleCtl.text.trim(),
        note: noteCtl.text.trim(),
      );
      await _load();
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();
    final (from, to) = _range();

    final shopNames = <String>[
      'All',
      ...app.shops
          .map((s) => (s['name'] ?? s['shopName'] ?? '').toString())
          .where((e) => e.isNotEmpty)
          .toSet(),
    ];

    final total = _rows.fold<num>(
        0, (s, e) => s + ((e['amount'] as num?) ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Other Expense'),
        actions: [
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExpenseDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<String>(
                  value: _view,
                  items: const ['Daily', 'Weekly', 'Monthly', 'Yearly']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _view = v);
                    _load();
                  },
                ),
                OutlinedButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _anchor,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) {
                      setState(() => _anchor = d);
                      _load();
                    }
                  },
                  child: Text(
                      '${_df.format(from)} → ${_df.format(to.subtract(const Duration(days: 1)))}'),
                ),
                DropdownButton<String>(
                  value: _shopFilter ?? 'All',
                  items: shopNames
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) {
                    setState(() => _shopFilter = (v == 'All') ? null : v);
                    _load();
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 0),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        _metric('Total Expense',
                            NumberFormat.currency(locale: 'en_US', symbol: r'$')
                                .format(total),
                            emphasize: true),
                      ],
                    ),
                  ),
                  ..._rows.map((e) {
                    final when = e['createdAt'] as DateTime? ??
                        DateTime.tryParse('${e['createdAt']}');
                    return ListTile(
                      leading: const Icon(Icons.receipt_long),
                      title: Text(
                          '${(e['title'] ?? 'Expense')}  •  ${(e['shopName'] ?? '-')}'),
                      subtitle: Text(
                          '${when != null ? _df.format(when) : ''}${(e['note'] ?? '').toString().isNotEmpty ? '  •  ${e['note']}' : ''}'),
                      trailing: Text(
                        NumberFormat.currency(locale: 'en_US', symbol: r'$')
                            .format((e['amount'] as num?) ?? 0),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _metric(String title, String value, {bool emphasize = false}) {
    final base = emphasize ? Colors.blue : Colors.grey;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: base.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: emphasize ? FontWeight.w800 : FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
