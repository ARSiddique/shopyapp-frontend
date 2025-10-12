// lib/screens/total_expense_screen.dart
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
  DateTime _anchor = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _loading = true;

  // totals (month)
  double _totalCash = 0;       // sales cash (month)
  double _cashPicked = 0;      // picked from cash_collect
  double _empExpense = 0;      // employee_expenses
  double _otherExpense = 0;    // expenses

  final _dfMon = DateFormat('MMMM yyyy');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  (DateTime from, DateTime toExcl) _monthBounds(DateTime m) =>
      (DateTime(m.year, m.month, 1), DateTime(m.year, m.month + 1, 1));

  Future<void> _load() async {
    setState(() => _loading = true);
    final app = context.read<AppDataProvider>();
    final (from, toExcl) = _monthBounds(_anchor);

    // 1) Sales cash total (month)
    final sales = await app.fetchSalesBetween(from: from, to: toExcl, shopName: null);
    double monthCash = 0;
    for (final s in sales) {
      final v = s['cash'];
      monthCash += (v is num) ? v.toDouble() : (double.tryParse('${v ?? 0}') ?? 0.0);
    }

    // 2) Cash picked (month)
    final picked = await app.sumCashPickedBetween(from: from, to: toExcl, shopName: 'All');

    // 3) Employee expense sum (month)
    final emp = await app.fetchEmployeeExpenseSumForMonth(_anchor, shopName: 'All');

    // 4) Other expense sum (month)
    await app.fetchOtherExpensesForMonth(_anchor, shopName: 'All');
    final oth = app.sumOtherExpenseMonth();

    if (!mounted) return;
    setState(() {
      _totalCash    = monthCash;
      _cashPicked   = picked;
      _empExpense   = emp;
      _otherExpense = oth;
      _loading = false;
    });
  }

  // Derived
  double get _totalExpense => _empExpense + _otherExpense;
  // cash in hand = cash picked - total expenses
  double get _cashInHand => _cashPicked - _totalExpense;
  // cash not picked = total cash - cash picked
  double get _cashNotPicked => _totalCash - _cashPicked;

  // Month nav
  void _changeMonth(int delta) {
    final m = DateTime(_anchor.year, _anchor.month + delta, 1);
    setState(() => _anchor = m);
    _load();
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchor,
      firstDate: DateTime(2022, 1, 1),
      lastDate: DateTime.now(),
      helpText: 'Pick any date in month',
    );
    if (picked != null && mounted) {
      setState(() => _anchor = DateTime(picked.year, picked.month, 1));
      _load();
    }
  }

  // Navigate
  void _openEmployeeBreakdown() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EmployeeExpenseBreakdownScreen(month: _anchor),
    ));
  }

  void _openOtherBreakdown() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => OtherExpenseBreakdownScreen(month: _anchor),
    ));
  }

  // Explain popups
  void _showCashInHandExplain() {
    final cp = _fmt(_cashPicked);
    final te = _fmt(_totalExpense);
    final res = _fmt(_cashInHand);
    showDialog(
      context: context,
      builder: (_) => _ExplainDialog(
        title: 'Total Cash in Hand',
        lines: [
          'Formula: Cash in hand = Cash picked − Total expenses',
          'Cash picked: $cp',
          'Total expenses: $te',
          'Result: $cp − $te = $res',
        ],
      ),
    );
  }

  void _showCashNotPickedExplain() {
    final tc = _fmt(_totalCash);
    final cp = _fmt(_cashPicked);
    final res = _fmt(_cashNotPicked);
    showDialog(
      context: context,
      builder: (_) => _ExplainDialog(
        title: 'Total Cash Not Picked',
        lines: [
          'Formula: Cash not picked = Total cash − Cash picked',
          'Total cash (sales cash): $tc',
          'Cash picked: $cp',
          'Result: $tc − $cp = $res',
        ],
      ),
    );
  }

  String _fmt(num v) => '\$${v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final title = 'Totals';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                children: [
                  // ===== Month Navigator (◀ Month ▶ + tap to calendar) =====
                  _MonthNav(
                    label: _dfMon.format(_anchor),
                    onPrev: () => _changeMonth(-1),
                    onNext: () => _changeMonth(1),
                    onTapCenter: _pickMonth,
                  ),
                  const SizedBox(height: 10),

                  // ===== MAIN BIG CARD: TOTAL EXPENSE =====
                  _BigStatCard(
                    label: 'Total Expense',
                    value: _fmt(_totalExpense),
                    valueColor: const Color(0xFFFF8A65),
                    subtitle: 'Employee + Other • ${_dfMon.format(_anchor)}',
                    onTap: () {
                      final emp = _fmt(_empExpense);
                      final oth = _fmt(_otherExpense);
                      final tot = _fmt(_totalExpense);
                      showDialog(
                        context: context,
                        builder: (_) => _ExplainDialog(
                          title: 'Total Expense',
                          lines: [
                            'Total Expense = Employee Expense + Other Expense',
                            'Employee: $emp',
                            'Other: $oth',
                            'Result: $emp + $oth = $tot',
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  // ===== Smaller stat: Total Sales Cash (requested) =====
                  _StatCard(
                    label: 'Total Sales Cash',
                    value: _fmt(_totalCash),
                    valueColor: const Color(0xFF00FFC6),
                    subtitle: 'All shops • ${_dfMon.format(_anchor)}',
                  ),
                  const SizedBox(height: 10),

                  // ===== Row: Employee / Other =====
                  _Row2(
                    left: _Tile(
                      title: 'Employee Expense',
                      value: _fmt(_empExpense),
                      valueColor: const Color(0xFFFFB74D),
                      onTap: _openEmployeeBreakdown,
                    ),
                    right: _Tile(
                      title: 'Other Expense',
                      value: _fmt(_otherExpense),
                      valueColor: const Color(0xFFFF6B6B),
                      onTap: _openOtherBreakdown,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // ===== Row: Picked / Cash in Hand =====
                  _Row2(
                    left: _Tile(
                      title: 'Total Cash Picked',
                      value: _fmt(_cashPicked),
                      valueColor: const Color(0xFF80CBC4),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => _ExplainDialog(
                            title: 'Total Cash Picked',
                            lines: [
                              'Sum of all picked amounts recorded in cash_collect.',
                              'Picked: ${_fmt(_cashPicked)}',
                            ],
                          ),
                        );
                      },
                    ),
                    right: _Tile(
                      title: 'Total Cash in Hand',
                      value: _fmt(_cashInHand),
                      valueColor: const Color(0xFFB2FF59),
                      onTap: _showCashInHandExplain,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // ===== Row: Not Picked =====
                  _Row2(
                    left: _Tile(
                      title: 'Total Cash Not Picked',
                      value: _fmt(_cashNotPicked),
                      valueColor: const Color(0xFFFFD54F),
                      onTap: _showCashNotPickedExplain,
                    ),
                    right: const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
    );
  }
}

/// ========================= UI bits =========================

class _MonthNav extends StatelessWidget {
  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onTapCenter;

  const _MonthNav({
    required this.label,
    required this.onPrev,
    required this.onNext,
    required this.onTapCenter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(255, 255, 255, 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.12)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous month',
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTapCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next month',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _Row2 extends StatelessWidget {
  final Widget left;
  final Widget right;
  const _Row2({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 10),
        Expanded(child: right),
      ],
    );
  }
}

class _BigStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final Color? valueColor;
  final VoidCallback? onTap;

  const _BigStatCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.valueColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(255, 255, 255, 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.white70)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: valueColor),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, style: const TextStyle(fontSize: 12, color: Colors.white60)),
          ],
        ],
      ),
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final Color? valueColor;

  const _StatCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container
    (
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(255, 255, 255, 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: valueColor),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, style: const TextStyle(fontSize: 12, color: Colors.white60)),
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String title;
  final String value;
  final Color? valueColor;
  final VoidCallback? onTap;

  const _Tile({
    required this.title,
    required this.value,
    this.valueColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(255, 255, 255, 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color.fromRGBO(255, 255, 255, 0.10),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w800, color: valueColor),
          ),
        ],
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class _ExplainDialog extends StatelessWidget {
  final String title;
  final List<String> lines;
  const _ExplainDialog({required this.title, required this.lines});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF121212),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: lines
            .map((l) => Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(l),
                  ),
                ))
            .toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        )
      ],
    );
  }
}
