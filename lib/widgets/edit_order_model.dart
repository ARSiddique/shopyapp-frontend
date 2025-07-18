import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

class EditOrderModal extends StatefulWidget {
  final Map<String, dynamic> orderData;

  const EditOrderModal({super.key, required this.orderData});

  @override
  State<EditOrderModal> createState() => _EditOrderModalState();
}

class _EditOrderModalState extends State<EditOrderModal> {
  late TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.orderData['amount'].toString(),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text("Edit Order"),
      content: TextField(
        controller: _amountController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: "Amount",
          prefixIcon: Icon(Icons.attach_money),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton.icon(
          onPressed: () {
            final newAmount = double.tryParse(_amountController.text.trim());
            if (newAmount != null && newAmount > 0) {
              final appData = Provider.of<AppDataProvider>(
                context,
                listen: false,
              );
              final updatedOrder = {...widget.orderData, 'amount': newAmount};
              appData.editOrder(updatedOrder);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Order updated successfully")),
              );

              Navigator.pop(context);
            }
          },
          icon: const Icon(Icons.save),
          label: const Text("Save"),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
