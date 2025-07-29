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
  String _product = '';
  int _quantity = 1;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final user = appData.loggedInUser ?? {};
    final role = (user['role'] ?? 'employee').toLowerCase();

    final assignedShops = role == 'employee'
        ? (user['assignedShops'] ?? []).cast<String>()
        : appData.shops
              .where((shop) => shop['isDeleted'] != true)
              .map<String>((s) => s['name'].toString())
              .toList();

    final isFormValid =
        _selectedShop != null && _product.trim().isNotEmpty && _quantity > 0;

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
              // Shop Dropdown
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
                validator: (value) =>
                    value == null ? 'Please select a shop' : null,
              ),
              const SizedBox(height: 16),

              // Product Field
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Product',
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) => setState(() => _product = val),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Enter product name'
                    : null,
              ),
              const SizedBox(height: 16),

              // Quantity Field
              TextFormField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
                initialValue: '1',
                onChanged: (val) {
                  final parsed = int.tryParse(val);
                  setState(
                    () => _quantity = parsed != null && parsed > 0 ? parsed : 1,
                  );
                },
                validator: (val) => (int.tryParse(val ?? '') ?? 0) <= 0
                    ? 'Invalid quantity'
                    : null,
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: _isSubmitting
                      ? const Text('Submitting...')
                      : const Text('Add Order'),
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
                              'product': _product.trim(),
                              'quantity': _quantity,
                              'employee': user['name'],
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
                                  content: Text('Order added successfully'),
                                ),
                              );
                            }
                          } catch (e) {
                            debugPrint('Error adding order: $e');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to add order'),
                              ),
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
