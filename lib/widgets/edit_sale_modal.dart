import 'package:flutter/material.dart';

class EditSaleModal extends StatefulWidget {
  final double initialAmount;
  final Function(double, String) onSubmit; // ✅ 2 parameters

  const EditSaleModal({
    super.key,
    required this.initialAmount,
    required this.onSubmit,
  });

  @override
  State<EditSaleModal> createState() => _EditSaleModalState();
}

class _EditSaleModalState extends State<EditSaleModal> {
  late TextEditingController _amountController;
  final TextEditingController _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.initialAmount.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    final newAmount = double.tryParse(_amountController.text.trim());
    final reason = _reasonController.text.trim();

    if (newAmount == null || newAmount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter a valid amount")));
      return;
    }

    if (reason.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Reason is required")));
      return;
    }

    widget.onSubmit(newAmount, reason);
    Navigator.pop(context); // ✅ Close modal after submit
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Edit Sale"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "New Amount",
              prefixIcon: Icon(Icons.attach_money),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: "Reason",
              prefixIcon: Icon(Icons.edit_note),
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
          child: const Text("Submit"),
        ),
      ],
    );
  }
}
