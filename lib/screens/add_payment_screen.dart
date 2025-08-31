import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

class AddPaymentScreen extends StatefulWidget {
  const AddPaymentScreen({super.key});

  @override
  State<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends State<AddPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _shop;
  double _amount = 0;
  String _toWholesaler = '';
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
    if (_shop == null && isEmployee) {
      _shop = selected ?? (user['assignedShops'] as List?)?.first?.toString();
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
        ? allActiveShops.map((s) => (s['name'] ?? '').toString()).where((n) => employeeShopNames.contains(n)).toList()
        : allActiveShops.map((s) => (s['name'] ?? '').toString()).toList();

    final valid = (_shop ?? '').isNotEmpty && _amount > 0 && _toWholesaler.trim().isNotEmpty && !_busy;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Payment')),
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

              // To Wholesaler
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'To Wholesaler',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _toWholesaler = v),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter wholesaler' : null,
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
                  label: Text(_busy ? 'Saving…' : 'Save Payment'),
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
      await app.addPayment(
        shopName: _shop!.trim(),
        amount: _amount,
        toWholesalerName: _toWholesaler.trim(),
        note: _note,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment added')));
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
