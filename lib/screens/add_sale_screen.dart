import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';
import 'package:intl/intl.dart';

class AddSaleScreen extends StatefulWidget {
  const AddSaleScreen({super.key});

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

      final existingSaleQuery = await FirebaseFirestore.instance
          .collection('sales')
          .where('shop', isEqualTo: shopName)
          .where('saleDate', isEqualTo: formattedDate)
          .limit(1)
          .get();

      if (existingSaleQuery.docs.isNotEmpty) {
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

      await FirebaseFirestore.instance.collection('sales').add(saleData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sale added successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
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
    final userRole = appData.loggedInUser?['role'] ?? 'employee';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Sale'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text('Select Shop'),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('shops')
                    .where('isDeleted', isEqualTo: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const CircularProgressIndicator();
                  final shops = snapshot.data!.docs;
                  return DropdownButtonFormField<String>(
                    value: _selectedShop,
                    items: shops
                        .map(
                          (doc) => DropdownMenuItem<String>(
                            value: doc['name'] as String,
                            child: Text(doc['name']),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _selectedShop = val),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => val == null ? 'Select a shop' : null,
                  );
                },
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
                      child: const Text('Submit Sale'),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}
