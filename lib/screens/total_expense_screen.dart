// lib/screens/total_expense_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

class TotalExpenseScreen extends StatefulWidget {
  const TotalExpenseScreen({super.key});

  @override
  State<TotalExpenseScreen> createState() => _TotalExpenseScreenState();
}

class _TotalExpenseScreenState extends State<TotalExpenseScreen> {
  DateTime anchor = DateTime.now();
  double empSum = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final app = context.read<AppDataProvider>();
    // Other expense list for the month (All shops, no shop filter)
    await app.fetchOtherExpensesForMonth(anchor, shopName: 'All');
    // Employee expense monthly total (All shops)
    empSum = await app.fetchEmployeeExpenseSumForMonth(anchor, shopName: 'All');
    if (mounted) setState(() {});
  }

  Future<void> _shiftMonth(int delta) async {
    setState(() => anchor = DateTime(anchor.year, anchor.month + delta, 1));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();
    final monthStr = DateFormat('MMMM yyyy').format(anchor);

    final other = app.sumOtherExpenseMonth(); // already fetched for month
    final total = empSum + other;

    return Scaffold(
      appBar: AppBar(title: const Text('Total Expense')),
      // Full-width total block at the bottom (no shop / no FAB)
      bottomNavigationBar: SafeArea(child: _totalTile(total)),
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
                      child: Text(
                        monthStr,
                        style: const TextStyle(fontWeight: FontWeight.w600),
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

              // Two tiles (Employee + Other)
              _tile('Employee expense', empSum),
              const SizedBox(height: 8),
              _tile('Other expense', other),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(String label, double amount, {bool bold = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                )),
          ),
          Text('\$${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              )),
        ],
      ),
    );
  }

  // Full-width bottom block
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
