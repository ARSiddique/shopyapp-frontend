// ✅ FINAL POLISHED VERSION OF AddSaleScreen WITH ADD + EDIT SUPPORT

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';
import 'package:intl/intl.dart';

class AddSaleScreen extends StatefulWidget {
  final Map<String, dynamic>? existingSale;
  const AddSaleScreen({super.key, this.existingSale});

  @override
  State<AddSaleScreen> createState() => _AddSaleScreenState();
}

class _AddSaleScreenState extends State<AddSaleScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedShop;
  DateTime _selectedDate = DateTime.now();
  final _cashController = TextEditingController();
  final _cardController = TextEditingController();
  final _otherController = TextEditingController();
  bool _isLoading = false;
  bool _isEditMode = false;
  String? _docId;

  @override
  void initState() {
    super.initState();
    final sale = widget.existingSale;
    if (sale != null) {
      _isEditMode = true;
      _docId = sale['id'];
      _selectedShop = sale['shop'];
      _cashController.text = (sale['cash'] ?? '').toString();
      _cardController.text = (sale['card'] ?? '').toString();
      _otherController.text = (sale['other'] ?? '').toString();
      if (sale['saleDate'] != null) {
        _selectedDate = DateFormat('yyyy-MM-dd').parse(sale['saleDate']);
      }
    }
  }

  @override
  void dispose() {
    _cashController.dispose();
    _cardController.dispose();
    _otherController.dispose();
    super.dispose();
  }

  Future<void> _submitSale() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedShop == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a shop')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final shopName = _selectedShop!;
      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final appData = Provider.of<AppDataProvider>(context, listen: false);
      final user = appData.loggedInUser;

      final saleData = {
        'shop': shopName,
        'employee': user?['name'] ?? '',
        'employeeId': user?['uid'],
        'cash': double.tryParse(_cashController.text.trim()) ?? 0,
        'card': double.tryParse(_cardController.text.trim()) ?? 0,
        'other': double.tryParse(_otherController.text.trim()) ?? 0,
        'total':
            (double.tryParse(_cashController.text.trim()) ?? 0) +
            (double.tryParse(_cardController.text.trim()) ?? 0) +
            (double.tryParse(_otherController.text.trim()) ?? 0),
        'saleDate': formattedDate,
        'createdAt': Timestamp.now(),
      };

      if (_isEditMode && _docId != null) {
        await FirebaseFirestore.instance
            .collection('sales')
            .doc(_docId)
            .update(saleData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sale updated successfully')),
          );
        }
      } else {
        final existingSaleQuery = await FirebaseFirestore.instance
            .collection('sales')
            .where('shop', isEqualTo: shopName)
            .where('saleDate', isEqualTo: formattedDate)
            .limit(1)
            .get();

        if (existingSaleQuery.docs.isNotEmpty) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Sale already exists for this shop on the selected date.',
              ),
            ),
          );
          setState(() => _isLoading = false);
          return;
        }
        await FirebaseFirestore.instance.collection('sales').add(saleData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sale added successfully')),
          );
        }
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final user = appData.loggedInUser ?? {};
    final assignedShops = appData.getAssignedShopsForUser(user['uid'] ?? '');
    final isMultiShop = assignedShops.length > 1;

    // ✅ Prevent crash: only assign if not empty
    if (_selectedShop == null && assignedShops.isNotEmpty) {
      _selectedShop = assignedShops.first;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Sale' : 'Add Sale'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text('Select Shop'),
              if (isMultiShop)
                DropdownButtonFormField<String>(
                  value: _selectedShop,
                  items: assignedShops
                      .map(
                        (shopName) => DropdownMenuItem<String>(
                          value: shopName,
                          child: Text(shopName),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _selectedShop = val),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val == null ? 'Select a shop' : null,
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_selectedShop ?? 'No Shop Assigned'),
                ),
              const SizedBox(height: 16),
              const Text('Select Date (Today or Yesterday)'),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Today'),
                    selected: isSameDay(_selectedDate, DateTime.now()),
                    onSelected: (_) =>
                        setState(() => _selectedDate = DateTime.now()),
                  ),
                  const SizedBox(width: 10),
                  ChoiceChip(
                    label: const Text('Yesterday'),
                    selected: isSameDay(
                      _selectedDate,
                      DateTime.now().subtract(const Duration(days: 1)),
                    ),
                    onSelected: (_) => setState(
                      () => _selectedDate = DateTime.now().subtract(
                        const Duration(days: 1),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cashController,
                decoration: const InputDecoration(labelText: 'Cash Amount'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: _cardController,
                decoration: const InputDecoration(labelText: 'Card Amount'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: _otherController,
                decoration: const InputDecoration(labelText: 'Other Amount'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _submitSale,
                      child: Text(_isEditMode ? 'Update Sale' : 'Submit Sale'),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  bool isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }
}
