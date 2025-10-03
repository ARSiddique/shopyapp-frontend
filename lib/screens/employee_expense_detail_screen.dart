import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

class EmployeeExpenseDetailScreen extends StatefulWidget {
  const EmployeeExpenseDetailScreen({
    super.key,
    required this.employeeName,
    this.employee,
  });

  final String employeeName;
  final Map<String, dynamic>? employee;

  @override
  State<EmployeeExpenseDetailScreen> createState() =>
      _EmployeeExpenseDetailScreenState();
}

class _EmployeeExpenseDetailScreenState
    extends State<EmployeeExpenseDetailScreen> {
  final _fmtDate = DateFormat('MMM d, yyyy');
  final _fmtTime = DateFormat('hh:mm a');

  DateTime _month = DateTime.now();
  bool _loading = false;

  // Current month rows for this employee
  List<Map<String, dynamic>> _rows = [];

  // Totals
  double _sumAdvance = 0; // Advance
  double _totalPaid = 0; // Payment + Advance
  double _remaining = 0;

  double get _monthlySalary {
    final v = widget.employee?['salary'];
    if (v is num) return v.toDouble();
    return double.tryParse('${v ?? ""}') ?? 0.0;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final from = DateTime(_month.year, _month.month, 1);
      final to = DateTime(_month.year, _month.month + 1, 1);

      final app = context.read<AppDataProvider>();
      final list = await app.fetchEmployeeExpenses(
        from: from,
        to: to,
        shopName: null, // shops disabled here
      );

      final mine = list
          .where((e) =>
              (e['employeeName'] ?? '').toString() == widget.employeeName)
          .toList()
        ..sort((a, b) {
          final A = (a['createdAt'] as DateTime?) ?? DateTime(2000);
          final B = (b['createdAt'] as DateTime?) ?? DateTime(2000);
          return B.compareTo(A);
        });

      double paid = 0.0, adv = 0.0;
      for (final r in mine) {
        final t = (r['type'] ?? '').toString().toLowerCase();
        final a = ((r['amount'] ?? 0) as num).toDouble();
        if (t == 'paid' || t == 'payment') {
          paid += a;
        } else if (t == 'advance') {
          adv += a;
        }
      }

      final totalPaid = (paid + adv).toDouble();
      final remaining =
          (_monthlySalary - totalPaid).clamp(0.0, double.infinity).toDouble();

      setState(() {
        _rows = mine;
        _sumAdvance = adv;
        _totalPaid = totalPaid;
        _remaining = remaining;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openAddOrEditSheet({
    String mode = 'add', // 'add' | 'edit'
    String? id,
    String presetType = 'paid', // paid | advance | other
    double? presetAmount,
    String? presetNote,
  }) async {
    final formKey = GlobalKey<FormState>();
    String type = presetType;
    final amountCtrl =
        TextEditingController(text: presetAmount?.toStringAsFixed(0) ?? '');
    final noteCtrl = TextEditingController(text: presetNote ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    mode == 'add' ? 'Add Employee Expense' : 'Edit Entry',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: type,
                    items: const [
                      DropdownMenuItem(value: 'paid', child: Text('Payment')),
                      DropdownMenuItem(value: 'advance', child: Text('Advance')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (v) => type = v ?? 'paid',
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) {
                      final d = double.tryParse(v ?? '');
                      if (d == null || d <= 0) return 'Enter amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final amt = double.parse(amountCtrl.text.trim());
                            final note = noteCtrl.text.trim();

                            final app = context.read<AppDataProvider>();

                            if (mode == 'add') {
                              await app.addEmployeeExpense(
                                shopName: 'All',
                                amount: amt,
                                type: type,
                                employeeName: widget.employeeName,
                                note: note.isEmpty ? null : note,
                              );
                            } else {
                              await app.updateEmployeeExpenseEntry(
                                id: id!,
                                amount: amt,
                                type: type,
                                note: note,
                              );
                            }

                            if (!mounted) return;
                            Navigator.pop(context);
                            await _load();
                          },
                          child: Text(mode == 'add' ? 'Save' : 'Update'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _money(double v) => NumberFormat.decimalPattern().format(v);

  String _typeTitle(String t) {
    t = t.toLowerCase();
    if (t == 'paid' || t == 'payment') return 'Payment';
    if (t == 'advance') return 'Advance';
    return 'Other';
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMM yyyy').format(_month);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.employeeName),
        actions: [
          if (_remaining > 0)
            TextButton.icon(
              onPressed: () => _openAddOrEditSheet(
                mode: 'add',
                presetType: 'paid',
                presetAmount: _remaining,
                presetNote: 'Remaining pay',
              ),
              icon: const Icon(Icons.payments_outlined),
              label: Text(_money(_remaining)),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddOrEditSheet(mode: 'add'),
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Compact month selector (single chip)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                  child: Row(
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () {
                          setState(() =>
                              _month = DateTime(_month.year, _month.month - 1, 1));
                          _load();
                        },
                      ),
                      Expanded(
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.calendar_month, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                monthLabel,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () {
                          setState(() =>
                              _month = DateTime(_month.year, _month.month + 1, 1));
                          _load();
                        },
                      ),
                    ],
                  ),
                ),

                // Slim totals
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Row(
                    children: [
                      Expanded(child: _pill('Total Paid', _money(_totalPaid))),
                      Expanded(child: _pill('Advance', _money(_sumAdvance))),
                      Expanded(child: _pill('Remaining Pay', _money(_remaining))),
                    ],
                  ),
                ),

                // Table
                Expanded(
                  child: _rows.isEmpty
                      ? const Center(child: Text('No entries'))
                      : _table(),
                ),
              ],
            ),
    );
  }

  Widget _pill(String title, String value) {
    final c = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.outline.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  Theme.of(context).textTheme.labelSmall?.copyWith(height: 1)),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

Widget _table() {
  // compact typography
  const headStyle = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700);
  const cellStyle = TextStyle(fontSize: 12);

  // fixed, small widths — tweak if needed
  const wType = 86.0;
  const wAmt  = 74.0;  // amount
  const wNote = 96.0;
  const wDate = 98.0;
  const wMenu = 30.0;

  final rows = _rows.map((m) {
    final id     = (m['id'] ?? '').toString();
    final type   = (m['type'] ?? '').toString();
    final amount = ((m['amount'] ?? 0) as num).toDouble();
    final note   = (m['note'] ?? '').toString();
    final dt     = (m['createdAt'] as DateTime?) ?? DateTime.now();

    return DataRow(
      cells: [
        DataCell(SizedBox(
          width: wType,
          child: Text(_typeTitle(type),
              style: cellStyle, overflow: TextOverflow.ellipsis, maxLines: 1),
        )),
        DataCell(SizedBox(
          width: wAmt,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(_money(amount), style: cellStyle, maxLines: 1),
          ),
        )),
        DataCell(SizedBox(
          width: wNote,
          child: Text(
            note.isEmpty ? '—' : note,
            style: cellStyle,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        )),
        DataCell(SizedBox(
          width: wDate,
          child: Text(_fmtDate.format(dt),
              style: cellStyle, overflow: TextOverflow.ellipsis, maxLines: 1),
        )),
        DataCell(SizedBox(width: wMenu, child: _rowMenu(id, type, amount, note))),
      ],
    );
  }).toList();

  return Scrollbar(
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Align(
        alignment: Alignment.topLeft,
        child: DataTable(
          // 🔧 super compact layout
          columnSpacing: 4,
          horizontalMargin: 4,
          headingRowHeight: 26,
          dataRowMinHeight: 26,
          dataRowMaxHeight: 30,
          dividerThickness: 0.4,
          // NOTE: don't use `numeric:true` so header aligns exactly like cells
          columns: const [
            DataColumn(
              label: SizedBox(width: wType, child: Text('Type', style: headStyle)),
            ),
            DataColumn(
              label: SizedBox(
                width: wAmt,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text('Amount', style: headStyle),
                ),
              ),
            ),
            DataColumn(
              label: SizedBox(width: wNote, child: Text('Note', style: headStyle)),
            ),
            DataColumn(
              label: SizedBox(width: wDate, child: Text('Date', style: headStyle)),
            ),
            DataColumn(
              label: SizedBox(width: wMenu, child: Text('', style: headStyle)),
            ),
          ],
          rows: rows,
        ),
      ),
    ),
  );
}

  Widget _rowMenu(String id, String type, double amount, String note) {
    return PopupMenuButton<String>(
      onSelected: (v) async {
        if (v == 'edit') {
          await _openAddOrEditSheet(
            mode: 'edit',
            id: id,
            presetType: (type == 'payment') ? 'paid' : type,
            presetAmount: amount,
            presetNote: note,
          );
        } else if (v == 'del') {
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Delete entry?'),
              content: const Text('This cannot be undone.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete')),
              ],
            ),
          );
          if (ok == true) {
            if (!mounted) return;
            await context
                .read<AppDataProvider>()
                .deleteEmployeeExpenseEntry(id);
            await _load();
          }
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit', child: Text('Edit')),
        PopupMenuItem(value: 'del', child: Text('Delete')),
      ],
    );
  }
}
