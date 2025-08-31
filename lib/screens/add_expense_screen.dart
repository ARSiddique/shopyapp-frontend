import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _shop;
  double _amount = 0;
  String _category = 'Misc';
  String? _note;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = context.read<AppDataProvider>();
    final user = app.loggedInUser ?? {};
    final role = (user['role'] ?? 'employee').toString().toLowerCase();
    final isEmployee = role == 'employee';
    final selected = app.selectedShopName;

    // defaulting
    if (_shop == null) {
      if (isEmployee) {
        _shop = selected ?? (user['assignedShops'] as List?)?.first?.toString();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();
    final user = app.loggedInUser ?? {};
    final role = (user['role'] ?? 'employee').toString().toLowerCase();
    final isEmployee = role == 'employee';

    final allActiveShops = app.shops.where((s) => (s['isDeleted'] ?? false) != true).toList();
    final employeeShopNames = ((user['assignedShops'] ?? []) as List).map((e) => e.toString()).toSet();
    final visibleShopNames = isEmployee
        ? allActiveShops
            .map((s) => (s['name'] ?? '').toString())
            .where((n) => employeeShopNames.contains(n))
            .toList()
        : allActiveShops.map((s) => (s['name'] ?? '').toString()).toList();

    final valid = (_shop ?? '').isNotEmpty && _amount > 0 && !_busy;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Expense')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Shop
              if (isEmployee)
                TextFormField(
                  readOnly: true,
                  initialValue: _shop ?? '',
                  decoration: const InputDecoration(
                    labelText: 'Shop',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Shop required' : null,
                )
              else
                DropdownButtonFormField<String>(
                  value: _shop,
                  decoration: const InputDecoration(
                    labelText: 'Shop',
                    border: OutlineInputBorder(),
                  ),
                  items: visibleShopNames.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                  onChanged: (v) => setState(() => _shop = v),
                  validator: (v) => (v == null || v.isEmpty) ? 'Select shop' : null,
                ),
              const SizedBox(height: 16),

              // Amount
              TextFormField(
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _amount = double.tryParse(v) ?? 0),
                validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Invalid amount' : null,
              ),
              const SizedBox(height: 16),

              // Category
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Rent', child: Text('Rent')),
                  DropdownMenuItem(value: 'Utility', child: Text('Utility')),
                  DropdownMenuItem(value: 'Misc', child: Text('Misc')),
                ],
                onChanged: (v) => setState(() => _category = v ?? 'Misc'),
              ),
              const SizedBox(height: 16),

              // Note
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                onChanged: (v) => _note = v,
              ),
              const SizedBox(height: 24),

              // Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: valid ? () => _submit(app) : null,
                  icon: _busy
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: Text(_busy ? 'Saving…' : 'Save Expense'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(AppDataProvider app) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await app.addExpense(
        shopName: _shop!.trim(),
        amount: _amount,
        category: _category,
        note: _note,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense added')));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
