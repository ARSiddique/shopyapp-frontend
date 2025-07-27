import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

class AddOrderScreen extends StatefulWidget {
  const AddOrderScreen({super.key});

  @override
  State<AddOrderScreen> createState() => _AddOrderScreenState();
}

class _AddOrderScreenState extends State<AddOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _itemsController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  String paymentType = "Cash";

 void _submitOrder() async {

    if (_formKey.currentState!.validate()) {
      final appData = Provider.of<AppDataProvider>(context, listen: false);
      final user = appData.loggedInUser;

      if (user == null || user['role'] != 'employee') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Only employees can submit orders")),
        );
        return;
      }

      final String employeeName = user['name'];
      final String shop = (user['assignedShops'] as List).isNotEmpty
          ? user['assignedShops'][0]
          : "Unknown";
      final int orderId = DateTime.now().millisecondsSinceEpoch;

      final order = {
        'id': orderId,
        'employee': employeeName,
        'shop': shop,
        'items': _itemsController.text.trim(),
        'amount': double.tryParse(_amountController.text.trim()) ?? 0,
        'payment': paymentType,
        'notes': _notesController.text.trim(),
      };

     await appData.addOrder(order);


     if (!mounted) return; // ✅ Safety check
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Order submitted successfully!")),
      );

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final user = appData.loggedInUser;
    final employeeName = user?['name'] ?? "Unknown";
    final assignedShop = user?['assignedShops']?.isNotEmpty == true
        ? user!['assignedShops'][0]
        : "Unknown";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Submit New Order"),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Display Info
              Text("Employee: $employeeName"),
              Text("Shop: $assignedShop"),
              
              const SizedBox(height: 20),

              // Items Ordered
              TextFormField(
                controller: _itemsController,
                decoration: const InputDecoration(labelText: "Items Ordered"),
                validator: (value) =>
                    value!.isEmpty ? "Please enter item details" : null,
              ),
              const SizedBox(height: 16),

              // Amount
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: "Amount (Rs.)"),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    value!.isEmpty ? "Please enter amount" : null,
              ),
              const SizedBox(height: 16),

              // Payment Type
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Payment Type"),
                  Row(
                    children: [
                      Radio(
                        value: "Cash",
                        groupValue: paymentType,
                        onChanged: (value) =>
                            setState(() => paymentType = value!),
                      ),
                      const Text("Cash"),
                      Radio(
                        value: "Card",
                        groupValue: paymentType,
                        onChanged: (value) =>
                            setState(() => paymentType = value!),
                      ),
                      const Text("Card"),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Notes (optional)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 30),

              ElevatedButton.icon(
                onPressed: _submitOrder,
                icon: const Icon(Icons.send),
                label: const Text("Submit Order"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
