import 'package:flutter/material.dart';
import '../utils/delete_shop_dialog.dart';

class ShopCard extends StatelessWidget {
  final String shopName;
  final int employees;
  final bool isOpen;
  final int orderCount;
  final VoidCallback onCheckIn;

  const ShopCard({
    super.key,
    required this.shopName,
    required this.employees,
    required this.isOpen,
    required this.orderCount,
    required this.onCheckIn,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isOpen ? Colors.green : Colors.grey,
              radius: 6,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shopName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Employees: $employees",
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Orders: $orderCount",
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.qr_code_scanner, color: Colors.deepPurple),
              tooltip: 'Check-In / Check-Out',
              onPressed: onCheckIn,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete Shop',
              onPressed: () {
                showDeleteShopDialog(
                  context: context,
                  shopName: shopName,
                  onConfirmed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("$shopName deleted successfully!"),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
