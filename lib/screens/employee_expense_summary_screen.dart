import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/app_data_provider.dart';

class EmployeeExpenseSummaryScreen extends StatefulWidget {
  const EmployeeExpenseSummaryScreen({super.key});

  @override
  State<EmployeeExpenseSummaryScreen> createState() =>
      _EmployeeExpenseSummaryScreenState();
}

class _EmployeeExpenseSummaryScreenState
    extends State<EmployeeExpenseSummaryScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  String _shop = 'All';
  bool _loading = false;

  // employee -> {salary, advance, paid, remaining}
  final Map<String, Map<String, double>> _byEmp = {};

  (DateTime from, DateTime to) _rangeForMonth(DateTime anchor) {
    final from = DateTime(anchor.year, anchor.month, 1);
    final to = DateTime(anchor.year, anchor.month + 1, 1);
    return (from, to);
  }

  Future<void> _load() async {
    final app = context.read<AppDataProvider>();
    setState(() => _loading = true);

    _byEmp.clear();

    // decide who to include
    final employees = app.employees
        .map((e) => (e['name'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toList();

    for (final emp in employees) {
      final m = await app.getEmployeeExpenseMonthTotals(
        shopName: _shop == 'All' ? '' : _shop, // when '' we’ll sum across shops
        employeeName: emp,
        monthAnchor: _month,
      );

      // When shop == 'All', above helper expects a shop filter.
      // If you want exact per-employee totals across all shops,
      // just fetch list and sum. We’ll fallback if shop == 'All'.
      if (_shop == 'All') {
        final (from, to) = _rangeForMonth(_month);
        final list = await app.fetchEmployeeExpenses(from: from, to: to, shopName: null);
        final me = list.where((x) => (x['employeeName'] ?? '') == emp);
        double salary = 0, advance = 0, paid = 0;
        for (final r in me) {
          final t = (r['type'] ?? 'salary').toString();
          final a = (r['amount'] ?? 0) as num;
          if (t == 'salary') salary += a;
          if (t == 'advance') advance += a;
          if (t == 'paid') paid += a;
        }
        _byEmp[emp] = {
          'salary': salary,
          'advance': advance,
          'paid': paid,
          'remaining': (salary + advance) - paid,
        };
      } else {
        _byEmp[emp] = {
          'salary': (m['salary'] ?? 0),
          'advance': (m['advance'] ?? 0),
          'paid': (m['paid'] ?? 0),
          'remaining': (m['remaining'] ?? 0),
        };
      }
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String _money(num v) =>
      NumberFormat.currency(locale: 'en_US', symbol: r'$').format(v);

  Future<void> _pickMonth() async {
    final now = _month;
    final d = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Pick any date in month',
    );
    if (d != null) {
      setState(() => _month = DateTime(d.year, d.month, 1));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();
    final shops = <String>['All', ...app.shops
        .map((s) => (s['name'] ?? s['shopName'] ?? '').toString())
        .where((e) => e.isNotEmpty)];

    // grand totals
    double gSalary = 0, gAdvance = 0, gPaid = 0;
    for (final v in _byEmp.values) {
      gSalary += v['salary'] ?? 0;
      gAdvance += v['advance'] ?? 0;
      gPaid += v['paid'] ?? 0;
    }
    final gRemain = (gSalary + gAdvance) - gPaid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Expense – Summary'),
        actions: [
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          // filters
          Padding(
            padding: const EdgeInsets.all(12),
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
                  items: shops
                      .map((s) => DropdownMenuItem<String>(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _shop = v);
                    _load();
                  },
                ),
              ],
            ),
          ),

          // grand summary
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                _metric('Salary', _money(gSalary)),
                _metric('Advance', _money(gAdvance)),
                _metric('Paid', _money(gPaid)),
                _metric('Remaining', _money(gRemain), emphasize: true),
              ],
            ),
          ),
          const Divider(height: 0),

          // table/list
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_byEmp.isEmpty)
            const Expanded(child: Center(child: Text('No data')))
          else
            Expanded(
              child: ListView.separated(
                itemCount: _byEmp.length,
                separatorBuilder: (_, __) => const Divider(height: 0),
                itemBuilder: (_, i) {
                  final emp = _byEmp.keys.elementAt(i);
                  final m = _byEmp[emp]!;
                  return ListTile(
                    title: Text(emp),
                    subtitle: Text(
                        'Salary: ${_money(m['salary'] ?? 0)}   •   Advance: ${_money(m['advance'] ?? 0)}   •   Paid: ${_money(m['paid'] ?? 0)}'),
                    trailing: Text(
                      _money(m['remaining'] ?? 0),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  );
                },
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
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 18, fontWeight: emphasize ? FontWeight.w800 : FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
