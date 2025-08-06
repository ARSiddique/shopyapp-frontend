import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/app_data_provider.dart';

class AddOrderScreen extends StatefulWidget {
  const AddOrderScreen({super.key});

  @override
  State<AddOrderScreen> createState() => _AddOrderScreenState();
}

class _AddOrderScreenState extends State<AddOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedShop;
  String _wholesalerName = '';
  double _orderAmount = 0.0;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final user = appData.loggedInUser ?? {};
    final role = (user['role'] ?? 'employee').toLowerCase();

    final isEmployee = role == 'employee';
    final assignedShops = isEmployee
        ? (user['assignedShops'] ?? []).cast<String>()
        : appData.shops
              .where((shop) => shop['isDeleted'] != true)
              .map<String>((s) => s['name'].toString())
              .toList();

    // If employee, auto-select their first assigned shop
    if (isEmployee && assignedShops.isNotEmpty && _selectedShop == null) {
      _selectedShop = assignedShops.first;
    }

    final isFormValid =
        _selectedShop != null &&
        _wholesalerName.trim().isNotEmpty &&
        _orderAmount > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Order'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Shop selection only for admin/manager
              if (!isEmployee)
                DropdownButtonFormField<String>(
                  value: _selectedShop,
                  decoration: const InputDecoration(
                    labelText: 'Select Shop',
                    border: OutlineInputBorder(),
                  ),
                  items: assignedShops
                      .map(
                        (shop) =>
                            DropdownMenuItem(value: shop, child: Text(shop)),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _selectedShop = val),
                  validator: (val) =>
                      val == null ? 'Please select a shop' : null,
                ),

              if (!isEmployee) const SizedBox(height: 16),

              // Wholesaler Name
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Wholesaler Name',
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) => setState(() => _wholesalerName = val),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Enter wholesaler name'
                    : null,
              ),
              const SizedBox(height: 16),

              // Order Amount
              TextFormField(
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Order Amount',
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) {
                  final parsed = double.tryParse(val);
                  setState(() => _orderAmount = parsed ?? 0.0);
                },
                validator: (val) => (double.tryParse(val ?? '') ?? 0.0) <= 0.0
                    ? 'Invalid amount'
                    : null,
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.send),
                  label: _isSubmitting
                      ? const Text('Submitting...')
                      : const Text('Submit Order'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: isFormValid && !_isSubmitting
                      ? () async {
                          if (!_formKey.currentState!.validate()) return;
                          setState(() => _isSubmitting = true);

                          try {
                            final newOrder = {
                              'shop': _selectedShop,
                              'wholesaler': _wholesalerName.trim(),
                              'amount': _orderAmount,
                              'employee': user['name'],
                              'status': 'Pending',
                              'createdAt': Timestamp.now(),
                            };

                            final docRef = await FirebaseFirestore.instance
                                .collection('orders')
                                .add(newOrder);

                            newOrder['id'] = docRef.id;
                            appData.addOrder(newOrder);

                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Order submitted successfully'),
                                ),
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }

                          if (mounted) setState(() => _isSubmitting = false);
                        }
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
