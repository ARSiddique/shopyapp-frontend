import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/app_data_provider.dart';
import 'employee_expense_breakdown_screen.dart';
import 'other_expense_breakdown_screen.dart';

class TotalExpenseScreen extends StatefulWidget {
  const TotalExpenseScreen({super.key});

  @override
  State<TotalExpenseScreen> createState() => _TotalExpenseScreenState();
}

class _TotalExpenseScreenState extends State<TotalExpenseScreen> {
  DateTime _anchor = DateTime.now();
  bool _loading = false;

  double _empSum = 0.0;
  double _otherSum = 0.0;

  double _cashTotal = 0.0;   // sales.cash
  double _cashPicked = 0.0;  // cash_collect (collected=true)
  double get _cashNotPicked => (_cashTotal - _cashPicked).clamp(0.0, double.infinity);

  (DateTime from, DateTime toExcl) _monthBounds(DateTime m) =>
      (DateTime(m.year, m.month, 1), DateTime(m.year, m.month + 1, 1));

  DateTime _lastDayInclusive(DateTime m) =>
      DateTime(m.year, m.month + 1, 0); // e.g., 2025-10-31

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final app = context.read<AppDataProvider>();
    final (from, toExcl) = _monthBounds(_anchor);
    final lastDayIncl = _lastDayInclusive(_anchor);

    try {
      final results = await Future.wait([
        app.fetchOtherExpenses(from: from, to: toExcl, shopName: null),
        app.fetchEmployeeExpenses(from: from, to: toExcl, shopName: null),
        app.fetchSalesBetween(from: from, to: toExcl, shopName: null),
        app.sumCashPickedBetween(from: from, to: lastDayIncl, shopName: null),
      ]);

      final otherList = (results[0] as List?) ?? const [];
      final empList   = (results[1] as List?) ?? const [];
      final salesList = (results[2] as List?) ?? const [];
      final picked    = (results[3] as num?)?.toDouble() ?? 0.0;

      double otherSum = 0.0;
      for (final e in otherList) {
        final v = (e as Map)['amount'];
        otherSum += v is num ? v.toDouble() : (double.tryParse('$v') ?? 0.0);
      }

      double empSum = 0.0;
      for (final e in empList) {
        final v = (e as Map)['amount'];
        empSum += v is num ? v.toDouble() : (double.tryParse('$v') ?? 0.0);
      }

      double cash = 0.0;
      for (final s in salesList) {
        final v = (s as Map)['cash'];
        cash += v is num ? v.toDouble() : (double.tryParse('$v') ?? 0.0);
      }

      if (!mounted) return;
      setState(() {
        _empSum = empSum;
        _otherSum = otherSum;
        _cashTotal = cash;
        _cashPicked = picked;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load totals: $e')),
      );
    }
  }

  Future<void> _shiftMonth(int delta) async {
    setState(() => _anchor = DateTime(_anchor.year, _anchor.month + delta, 1));
    await _load();
  }

  String _fmt(double v) => '\$${v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final monthStr = DateFormat('MMMM yyyy').format(_anchor);
    final totalExpense = _empSum + _otherSum;
    final totalCashInHand = (_cashPicked - totalExpense);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Total Expense'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      bottomNavigationBar: SafeArea(child: _totalTile(totalExpense)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _loading ? null : () => _shiftMonth(-1),
                  ),
                  Expanded(
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(monthStr, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _loading ? null : () => _shiftMonth(1),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_loading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else
                Expanded(
                  child: ListView(
                    children: [
                      _tile(
                        'Employee expense',
                        _empSum,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EmployeeExpenseBreakdownScreen(month: _anchor),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _tile(
                        'Other expense',
                        _otherSum,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OtherExpenseBreakdownScreen(month: _anchor),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _tile(
                        'Total cash in hand',
                        totalCashInHand,
                        bold: true,
                        onTap: _showCashInHandBreakdown,
                      ),
                      const SizedBox(height: 8),
                      _tile(
                        'Cash not picked',
                        _cashNotPicked,
                        onTap: _showCashNotPickedBreakdown,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(String label, double amount, {bool bold = false, VoidCallback? onTap}) {
    final content = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w600))),
          Text(_fmt(amount), style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: content);
  }

  Widget _totalTile(double total) {
    return Container(
      width: double.infinity,
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Expanded(child: Text('Total Expense', style: TextStyle(fontWeight: FontWeight.bold))),
          Text(_fmt(total), style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showCashInHandBreakdown() {
    final (from, toExcl) = _monthBounds(_anchor);
    final month = DateFormat('MMMM yyyy').format(_anchor);
    final totalExpense = _empSum + _otherSum;
    final cashInHand = (_cashPicked - totalExpense);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Total Cash in Hand'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(month),
            const SizedBox(height: 8),
            _line('Cash Picked (collected):', _cashPicked),
            _line('Total Expenses (Emp + Other):', totalExpense),
            const Divider(),
            _line('Cash in Hand = Picked − Expenses:', cashInHand, bold: true),
            const SizedBox(height: 8),
            Text('Range: ${DateFormat('dd MMM').format(from)} – ${DateFormat('dd MMM').format(toExcl.subtract(const Duration(days: 1)))}'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  void _showCashNotPickedBreakdown() {
    final (from, toExcl) = _monthBounds(_anchor);
    final month = DateFormat('MMMM yyyy').format(_anchor);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cash Not Picked'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(month),
            const SizedBox(height: 8),
            _line('Total Cash (Sales – cash):', _cashTotal),
            _line('Cash Picked (Collected):', _cashPicked),
            const Divider(),
            _line('Not Picked = Total Cash − Picked:', _cashNotPicked, bold: true),
            const SizedBox(height: 8),
            Text('Range: ${DateFormat('dd MMM').format(from)} – ${DateFormat('dd MMM').format(toExcl.subtract(const Duration(days: 1)))}'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Widget _line(String k, double v, {bool bold = false}) {
    return Row(
      children: [
        Expanded(child: Text(k)),
        Text(_fmt(v), style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }
}
