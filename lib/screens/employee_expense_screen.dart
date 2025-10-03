// lib/screens/employee_expense_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/app_data_provider.dart';

class EmployeeExpenseScreen extends StatefulWidget {
  /// If provided, the screen is locked to this employee (no employee dropdown).
  const EmployeeExpenseScreen({super.key, this.employeeName});

  final String? employeeName;

  @override
  State<EmployeeExpenseScreen> createState() => _EmployeeExpenseScreenState();
}

class _EmployeeExpenseScreenState extends State<EmployeeExpenseScreen> {
  final _df = DateFormat('MMM d, yyyy', 'en_US');

  // filters
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  String _shop = 'All';
  String _employee = 'All';
  String _type = 'All'; // salary | advance | paid | All

  bool _loading = false;
  List<Map<String, dynamic>> _rows = [];

  // form controllers
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String? _formShop;
  String? _formEmployee;
  String _formType = 'salary';

  bool get _lockedEmployee => (widget.employeeName != null && widget.employeeName!.trim().isNotEmpty);

  @override
  void initState() {
    super.initState();
    // If a specific employee is provided, lock the filter to that name.
    if (_lockedEmployee) {
      _employee = widget.employeeName!.trim();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  (DateTime from, DateTime to) _rangeForMonth(DateTime anchor) {
    final from = DateTime(anchor.year, anchor.month, 1);
    final to = DateTime(anchor.year, anchor.month + 1, 1);
    return (from, to);
  }

  Future<void> _load() async {
    final app = context.read<AppDataProvider>();
    setState(() => _loading = true);

    final (from, to) = _rangeForMonth(_month);
    var list = await app.fetchEmployeeExpenses(
      from: from,
      to: to,
      shopName: _shop == 'All' ? null : _shop,
    );

    // Apply employee filter (locked if employeeName passed)
    final selectedEmployee = _lockedEmployee ? widget.employeeName! : _employee;
    if (selectedEmployee != 'All') {
      list = list.where((e) => (e['employeeName'] ?? '') == selectedEmployee).toList();
    }

    if (_type != 'All') {
      list = list.where((e) => (e['type'] ?? '') == _type).toList();
    }

    list.sort((a, b) {
      final da = (a['createdAt'] as DateTime?) ?? DateTime(2000);
      final db = (b['createdAt'] as DateTime?) ?? DateTime(2000);
      return db.compareTo(da);
    });

    if (!mounted) return;
    setState(() {
      _rows = list;
      _loading = false;
    });
  }

  String _money(num v) =>
      NumberFormat.currency(locale: 'en_US', symbol: r'$').format(v);

  Future<void> _pickMonth() async {
    final now = _month;
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Pick any date in month',
    );
    if (picked != null) {
      setState(() => _month = DateTime(picked.year, picked.month, 1));
      _load();
    }
  }

  Future<void> _openAddDialog() async {
    final app = context.read<AppDataProvider>();
    final shops = [
      ...app.shops
          .map((s) => (s['name'] ?? s['shopName'] ?? '').toString())
          .where((e) => e.trim().isNotEmpty)
    ];
    final employees = [
      ...app.employees.map((e) => (e['name'] ?? '').toString()).where((e) => e.trim().isNotEmpty)
    ];

    _formShop = _shop == 'All' ? (shops.isNotEmpty ? shops.first : null) : _shop;

    // If locked, always use the provided employee; otherwise use current filter or first in list
    if (_lockedEmployee) {
      _formEmployee = widget.employeeName!;
    } else {
      _formEmployee =
          _employee == 'All' ? (employees.isNotEmpty ? employees.first : null) : _employee;
    }

    _formType = 'salary';
    _amountCtrl.text = '';
    _noteCtrl.text = '';

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Employee Expense'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Shop
              DropdownButtonFormField<String>(
                value: _formShop,
                items: shops
                    .map((s) => DropdownMenuItem<String>(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => _formShop = v,
                decoration: const InputDecoration(labelText: 'Shop'),
              ),
              const SizedBox(height: 8),

              // Employee (hidden when locked; show read-only preview instead)
              if (_lockedEmployee)
                TextFormField(
                  enabled: false,
                  initialValue: widget.employeeName!,
                  decoration: const InputDecoration(labelText: 'Employee'),
                )
              else
                DropdownButtonFormField<String>(
                  value: _formEmployee,
                  items: employees
                      .map((n) => DropdownMenuItem<String>(value: n, child: Text(n)))
                      .toList(),
                  onChanged: (v) => _formEmployee = v,
                  decoration: const InputDecoration(labelText: 'Employee'),
                ),

              const SizedBox(height: 8),
              // Type
              DropdownButtonFormField<String>(
                value: _formType,
                items: const [
                  DropdownMenuItem(value: 'salary', child: Text('Salary')),
                  DropdownMenuItem(value: 'advance', child: Text('Advance')),
                  DropdownMenuItem(value: 'paid', child: Text('Paid')),
                ],
                onChanged: (v) => _formType = v ?? 'salary',
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              const SizedBox(height: 8),
              // Amount
              TextFormField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noteCtrl,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
        ],
      ),
    );

    if (ok == true) {
      final amount = double.tryParse(_amountCtrl.text) ?? 0;
      if ((_formShop ?? '').isEmpty || (_formEmployee ?? '').isEmpty || amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shop, Employee and valid Amount required')),
        );
        return;
      }
      await app.addEmployeeExpenseEntry(
        shopName: _formShop!,
        employeeName: _formEmployee!,
        amount: amount,
        type: _formType,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        when: DateTime.now(),
      );
      _load();
    }
  }

  Future<void> _editRow(Map<String, dynamic> row) async {
    final app = context.read<AppDataProvider>();
    final ctrlAmt = TextEditingController(text: (row['amount'] ?? 0).toString());
    final ctrlNote = TextEditingController(text: (row['note'] ?? '').toString());
    String type = (row['type'] ?? 'salary').toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Expense'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: type,
                items: const [
                  DropdownMenuItem(value: 'salary', child: Text('Salary')),
                  DropdownMenuItem(value: 'advance', child: Text('Advance')),
                  DropdownMenuItem(value: 'paid', child: Text('Paid')),
                ],
                onChanged: (v) => type = v ?? 'salary',
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: ctrlAmt,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: ctrlNote,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Update')),
        ],
      ),
    );

    if (ok == true) {
      final amt = double.tryParse(ctrlAmt.text) ?? -1;
      if (amt <= 0) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Enter valid amount')));
        return;
      }
      await app.updateEmployeeExpenseEntry(
        id: row['id'].toString(),
        amount: amt,
        type: type,
        note: ctrlNote.text.trim(),
      );
      _load();
    }
  }

  Future<void> _deleteRow(Map<String, dynamic> row) async {
    final app = context.read<AppDataProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this expense?'),
        content: Text(
          'Employee: ${row['employeeName']}\n'
          'Amount: ${_money(row['amount'] ?? 0)}\n'
          'Type: ${(row['type'] ?? '').toString().toUpperCase()}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await app.deleteEmployeeExpenseEntry(row['id'].toString());
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();

    final shopNames = <String>{
      'All',
      ...app.shops
          .map((s) => (s['name'] ?? s['shopName'] ?? '').toString())
          .where((e) => e.trim().isNotEmpty),
    }.toList();

    final employeeNames = <String>{
      'All',
      ...app.employees
          .map((e) => (e['name'] ?? '').toString())
          .where((e) => e.isNotEmpty),
    }.toList();

    // summary for current filter (month x shop x employee)
    double sumSalary = 0, sumAdvance = 0, sumPaid = 0;
    for (final r in _rows) {
      final t = (r['type'] ?? '').toString();
      final a = (r['amount'] ?? 0) as num;
      if (t == 'salary') sumSalary += a;
      if (t == 'advance') sumAdvance += a;
      if (t == 'paid') sumPaid += a;
    }
    final remaining = (sumSalary + sumAdvance) - sumPaid;

    final titleText = _lockedEmployee
        ? 'Employee Expenses — ${widget.employeeName}'
        : 'Employee Expenses';

    return Scaffold(
      appBar: AppBar(
        title: Text(titleText),
        actions: [
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: _openAddDialog, icon: const Icon(Icons.add)),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          // filters
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: _pickMonth,
                  child: Text(DateFormat('MMM yyyy').format(_month)),
                ),
                DropdownButton<String>(
                  value: _shop,
                  items: shopNames
                      .map((s) => DropdownMenuItem<String>(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _shop = v);
                    _load();
                  },
                ),

                // Hide the employee dropdown if locked to a specific employee
                if (!_lockedEmployee)
                  DropdownButton<String>(
                    value: _employee,
                    items: employeeNames
                        .map((n) => DropdownMenuItem<String>(value: n, child: Text(n)))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _employee = v);
                      _load();
                    },
                  )
                else
                  InputChip(
                    label: Text(widget.employeeName!),
                    onDeleted: null, // read-only; indicates locked filter
                  ),

                DropdownButton<String>(
                  value: _type,
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All Types')),
                    DropdownMenuItem(value: 'salary', child: Text('Salary')),
                    DropdownMenuItem(value: 'advance', child: Text('Advance')),
                    DropdownMenuItem(value: 'paid', child: Text('Paid')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _type = v);
                    _load();
                  },
                ),
              ],
            ),
          ),

          // summary strip
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: Row(
              children: [
                _metric('Salary', _money(sumSalary)),
                _metric('Advance', _money(sumAdvance)),
                _metric('Paid', _money(sumPaid)),
                _metric('Remaining', _money(remaining), emphasize: true),
              ],
            ),
          ),
          const Divider(height: 0),

          // list
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_rows.isEmpty)
            const Expanded(child: Center(child: Text('No expenses found')))
          else
            Expanded(
              child: ListView.separated(
                itemCount: _rows.length,
                separatorBuilder: (_, __) => const Divider(height: 0),
                itemBuilder: (_, i) {
                  final r = _rows[i];
                  final created = (r['createdAt'] as DateTime?) ?? DateTime.now();
                  final title =
                      '${r['employeeName'] ?? '-'} • ${(r['type'] ?? '').toString().toUpperCase()}';
                  final subtitle =
                      '${r['shopName'] ?? '-'}  •  ${_df.format(created)}  •  ${r['note'] ?? ''}';
                  return ListTile(
                    title: Text(title),
                    subtitle: Text(subtitle),
                    trailing: Text(
                      _money((r['amount'] ?? 0) as num),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onTap: () => _editRow(r),
                    onLongPress: () => _deleteRow(r),
                  );
                },
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
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
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
