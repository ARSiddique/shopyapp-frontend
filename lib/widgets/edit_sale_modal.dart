import 'package:flutter/material.dart';

class EditSaleModal extends StatefulWidget {
  final double initialAmount;
  final Function(double) onSubmit;

  const EditSaleModal({
    super.key,
    required this.initialAmount,
    required this.onSubmit,
  });

  @override
  State<EditSaleModal> createState() => _EditSaleModalState();
}

class _EditSaleModalState extends State<EditSaleModal> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialAmount.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final newAmount = double.tryParse(_controller.text.trim());
    if (newAmount != null && newAmount > 0) {
      widget.onSubmit(newAmount);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter a valid amount")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Edit Sale Amount"),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: "Amount",
          prefixIcon: Icon(Icons.attach_money),
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
          child: const Text("Save"),
        ),
      ],
    );
  }
}
