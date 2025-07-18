import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';
import '../widgets/edit_sale_modal.dart';

class AddSaleScreen extends StatefulWidget {
  const AddSaleScreen({super.key});

  @override
  State<AddSaleScreen> createState() => _AddSaleScreenState();
}

class _AddSaleScreenState extends State<AddSaleScreen> {
  final TextEditingController amountController = TextEditingController();
  Timer? _countdownTimer;
  Duration? _remainingTime;
  Map<String, dynamic>? _lastSale;

  @override
  void initState() {
    super.initState();
    _initCountdown();
  }

  void _initCountdown() {
    final appData = Provider.of<AppDataProvider>(context, listen: false);
    final user = appData.loggedInUser;
    if (user == null) return;

    final employeeName = user['name'];
    final sales = appData.allSales
        .where((s) => s['employee'] == employeeName)
        .toList();

    if (sales.isNotEmpty) {
      final recentSale = sales.last;
      final createdAt = recentSale['createdAt'] as DateTime;
      final elapsed = DateTime.now().difference(createdAt);

      if (elapsed.inMinutes < 5) {
        setState(() {
          _lastSale = recentSale;
          _remainingTime = Duration(minutes: 5) - elapsed;
        });
        _startTimer();
      }
    }
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingTime != null && _remainingTime!.inSeconds > 0) {
        setState(() {
          _remainingTime = _remainingTime! - const Duration(seconds: 1);
        });
      } else {
        _countdownTimer?.cancel();
        setState(() {
          _remainingTime = null;
          _lastSale = null;
        });
      }
    });
  }

  void _submitSale() {
    final appData = Provider.of<AppDataProvider>(context, listen: false);
    final amount = double.tryParse(amountController.text.trim());

    if (amount != null && amount > 0) {
      final sale = {
        'id': DateTime.now().millisecondsSinceEpoch,
        'amount': amount,
        'employee': appData.loggedInUser?['name'],
        'shop': appData.loggedInUser?['assignedShops']?[0] ?? '',
        'createdAt': DateTime.now(),
      };
      appData.addSale(sale);
      amountController.clear();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sale added successfully')));

      _initCountdown();
    }
  }

  void _editLastSale() {
    if (_lastSale == null) return;

    showDialog(
      context: context,
      builder: (_) => EditSaleModal(
        initialAmount: _lastSale!['amount'],
        onSubmit: (updatedAmount) {
          final appData = Provider.of<AppDataProvider>(context, listen: false);
          appData.updateSaleAmount(_lastSale!['id'], updatedAmount);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sale updated successfully')),
          );

          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Sale"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Sale Amount",
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _submitSale,
              icon: const Icon(Icons.save),
              label: const Text("Submit Sale"),
            ),
            if (_remainingTime != null)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Column(
                  children: [
                    Text(
                      "⏱ Edit Available: ${_remainingTime!.inMinutes.remainder(60).toString().padLeft(2, '0')}:${_remainingTime!.inSeconds.remainder(60).toString().padLeft(2, '0')}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _editLastSale,
                      icon: const Icon(Icons.edit),
                      label: const Text("Edit Last Sale"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
