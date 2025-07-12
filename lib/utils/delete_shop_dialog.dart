// utils/delete_shop_dialog.dart

import 'package:flutter/material.dart';

Future<void> showDeleteShopDialog({
  required BuildContext context,
  required String shopName,
  required Function onConfirmed,
}) async {
  final TextEditingController codeController = TextEditingController();
  const ownerCode = '123456'; // Simulate for now

  return showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Confirm Deletion"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Enter Owner Code to delete \"$shopName\""),
          const SizedBox(height: 12),
          TextField(
            controller: codeController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: "Owner Code",
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
          onPressed: () {
            if (codeController.text == ownerCode) {
              Navigator.pop(context);
              onConfirmed();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Invalid Owner Code")),
              );
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text("Delete"),
        ),
      ],
    ),
  );
}
