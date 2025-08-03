import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/app_data_provider.dart';

class AddSaleScreen extends StatefulWidget {
  const AddSaleScreen({super.key});

  @override
  State<AddSaleScreen> createState() => _AddSaleScreenState();
}

class _AddSaleScreenState extends State<AddSaleScreen> {
  final _formKey = GlobalKey<FormState>();
  final cashController = TextEditingController();
  final cardController = TextEditingController();
  final otherController = TextEditingController();
  String _selectedDay = 'today';
  bool _isSubmitting = false;

  bool hasSubmittedForDate(DateTime date, String employeeName) {
    final appData = Provider.of<AppDataProvider>(context, listen: false);
    return appData.sales.any((sale) {
      final createdAt = sale['createdAt'];
      final saleDate = createdAt is Timestamp
          ? createdAt.toDate()
          : (createdAt is DateTime ? createdAt : DateTime.now());
      return saleDate.year == date.year &&
          saleDate.month == date.month &&
          saleDate.day == date.day &&
          sale['employee'] == employeeName;
    });
  }

  Future<void> _submitSale() async {
    if (!_formKey.currentState!.validate()) return;
    final appData = Provider.of<AppDataProvider>(context, listen: false);
    final user = appData.loggedInUser;
    if (user == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final selectedDate = _selectedDay == 'today' ? today : yesterday;

    final alreadySubmitted = hasSubmittedForDate(selectedDate, user['name']);
    if (alreadySubmitted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sale for $_selectedDay already submitted!')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Submission'),
        content: Text('Submit sale for $_selectedDay?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed != true) return;

    final double cash = double.tryParse(cashController.text.trim()) ?? 0;
    final double card = double.tryParse(cardController.text.trim()) ?? 0;
    final double other = double.tryParse(otherController.text.trim()) ?? 0;
    final double total = cash + card + other;

    if (total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter at least one valid amount')),
      );
      return;
    }

    final sale = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'employee': user['name'],
      'shop': user['assignedShops']?[0] ?? '',
      'cash': cash,
      'card': card,
      'other': other,
      'total': total,
      'createdAt': DateTime.now(),
      'date': Timestamp.fromDate(selectedDate),
    };

    setState(() => _isSubmitting = true);
    await appData.addSale(sale);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sale submitted successfully')),
    );

    cashController.clear();
    cardController.clear();
    otherController.clear();
  }

  @override
  void dispose() {
    cashController.dispose();
    cardController.dispose();
    otherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AppDataProvider>(context).loggedInUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('User not found')));
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final canSubmitYesterday = !hasSubmittedForDate(yesterday, user['name']);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Sale')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (canSubmitYesterday)
                DropdownButtonFormField<String>(
                  value: _selectedDay,
                  decoration: const InputDecoration(
                    labelText: 'Select Date',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'today', child: Text('Today')),
                    DropdownMenuItem(
                      value: 'yesterday',
                      child: Text('Yesterday'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _selectedDay = value ?? 'today'),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: cashController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cash',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: cardController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Card',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: otherController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Other',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitSale,
                icon: const Icon(Icons.check),
                label: const Text('Submit Sale'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
