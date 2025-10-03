// lib/screens/other_expense_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

const double _kRowHeight = 64;

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
      shopName: null, // all shops
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
    final noteCtl = TextEditingController();
    DateTime picked = DateTime.now();

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('Add Other Expense'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtl,
                    decoration: const InputDecoration(labelText: 'Title'),
                    textInputAction: TextInputAction.next,
                  ),
                  TextField(
                    controller: amountCtl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount'),
                    textInputAction: TextInputAction.next,
                  ),
                  TextField(
                    controller: noteCtl,
                    decoration:
                        const InputDecoration(labelText: 'Note (optional)'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Date:'),
                      const SizedBox(width: 8),
                      Text(DateFormat('yyyy-MM-dd').format(picked)),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate: picked,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (d != null) {
                            setLocal(() => picked = d);
                          }
                        },
                        child: const Text('Pick'),
                      )
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final title = titleCtl.text.trim();
                  final amount = double.tryParse(amountCtl.text.trim()) ?? 0.0;
                  final note = noteCtl.text.trim();
                  if (title.isEmpty || amount <= 0) return;

                  await context.read<AppDataProvider>().addOtherExpenseEntry(
                        shopName: '', // not used (global)
                        amount: amount,
                        title: title,
                        note: note.isEmpty ? null : note,
                        when: picked,
                      );
                  if (!mounted) return;
                  Navigator.of(ctx).pop();
                  await _load();
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editExpenseDialog(Map<String, dynamic> item) async {
    final titleCtl =
        TextEditingController(text: (item['title'] ?? '').toString());
    final amountCtl = TextEditingController(
      text: ((item['amount'] as num?)?.toStringAsFixed(2) ?? ''),
    );
    final noteCtl =
        TextEditingController(text: (item['note'] ?? '').toString());
    DateTime picked = (item['createdAt'] is DateTime)
        ? item['createdAt'] as DateTime
        : DateTime.now();

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('Edit Expense'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtl,
                    decoration: const InputDecoration(labelText: 'Title'),
                    textInputAction: TextInputAction.next,
                  ),
                  TextField(
                    controller: amountCtl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount'),
                    textInputAction: TextInputAction.next,
                  ),
                  TextField(
                    controller: noteCtl,
                    decoration:
                        const InputDecoration(labelText: 'Note (optional)'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Date:'),
                      const SizedBox(width: 8),
                      Text(DateFormat('yyyy-MM-dd').format(picked)),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate: picked,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (d != null) {
                            setLocal(() => picked = d);
                          }
                        },
                        child: const Text('Pick'),
                      )
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final title = titleCtl.text.trim();
                  final amount = double.tryParse(amountCtl.text.trim()) ?? -1;
                  final note = noteCtl.text.trim();
                  if (title.isEmpty || amount <= 0) return;

                  await context.read<AppDataProvider>().updateOtherExpenseEntry(
                        id: (item['id'] ?? '').toString(),
                        amount: amount,
                        title: title,
                        note: note.isEmpty ? null : note,
                        when: picked,
                      );
                  if (!mounted) return;
                  Navigator.of(ctx).pop();
                  await _load();
                },
                child: const Text('Update'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(String id) async {
    final app = context.read<AppDataProvider>(); // capture before await
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await app.deleteOtherExpenseEntry(id);
      if (!mounted) return;
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthStr = DateFormat('MMMM yyyy').format(_anchor);
    final subtle =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    final stroke = Theme.of(context).dividerColor.withValues(alpha: 0.6);

    return Scaffold(
      appBar: AppBar(title: const Text('Other Expenses')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addExpenseDialog,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: SafeArea(child: _totalTile(_total, context)),
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
                        border: Border.all(color: stroke),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        monthStr,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: _items.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, i) {
                                final m = _items[i];
                                final id = (m['id'] ?? '').toString();
                                final title = (m['title'] ?? '').toString();
                                final amount =
                                    (m['amount'] as num?)?.toDouble() ?? 0.0;
                                final note = (m['note'] ?? '').toString();
                                final date = m['createdAt'] as DateTime?;
                                final subtitle = [
                                  if (note.isNotEmpty) note,
                                  if (date != null)
                                    DateFormat('yyyy-MM-dd').format(date),
                                ].join(' • ');

                                return Container(
                                  height: _kRowHeight,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: stroke),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (subtitle.isNotEmpty)
                                              Text(
                                                subtitle,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: subtle,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Text('\$${amount.toStringAsFixed(2)}'),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        tooltip: 'Edit',
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: () =>
                                            _editExpenseDialog(m),
                                      ),
                                      IconButton(
                                        tooltip: 'Delete',
                                        icon:
                                            const Icon(Icons.delete_outline),
                                        onPressed: () =>
                                            _confirmDelete(id),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _totalTile(double total, BuildContext context) {
    final stroke = Theme.of(context).dividerColor.withValues(alpha: 0.6);
    return Container(
      width: double.infinity,
      height: _kRowHeight,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border.all(color: stroke),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Total Expense',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            '\$${total.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
