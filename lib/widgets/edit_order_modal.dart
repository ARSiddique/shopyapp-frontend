import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

class EditOrderModal extends StatefulWidget {
  final Map<String, dynamic> orderData;
  final String type; // "order" or "sale"

  const EditOrderModal({
    super.key,
    required this.orderData,
    this.type = "order",
  });

  @override
  State<EditOrderModal> createState() => _EditOrderModalState();
}

class _EditOrderModalState extends State<EditOrderModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.orderData['amount'].toString(),
    );
    _notesController = TextEditingController(
      text: widget.orderData['notes'] ?? '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final appData = Provider.of<AppDataProvider>(context, listen: false);
      final updated = {
        ...widget.orderData,
        'amount': double.tryParse(_amountController.text) ?? 0.0,
        'notes': _notesController.text,
      };

      if (widget.type == 'order') {
        appData.editOrder(updated);
      } else {
        appData.editSale(updated);
      }

      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Edit ${widget.type == 'order' ? 'Order' : 'Sale'}"),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Amount"),
              validator: (val) =>
                  val == null || val.isEmpty ? "Enter amount" : null,
            ),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: "Notes (optional)"),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Cancel"),
        ),
        ElevatedButton(onPressed: _submit, child: const Text("Save Changes")),
      ],
    );
  }
}
