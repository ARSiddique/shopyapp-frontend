import 'package:flutter/material.dart';
import '../utils/delete_shop_dialog.dart';

class ShopCard extends StatelessWidget {
  final String shopName;
  final int employees;
  final bool isOpen;
  final int orderCount; // ✅ NEW
  final VoidCallback onCheckIn;

  const ShopCard({
    super.key,
    required this.shopName,
    required this.employees,
    required this.isOpen,
    required this.orderCount, // ✅ NEW
    required this.onCheckIn,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // 🏪 Status dot
            CircleAvatar(
              backgroundColor: isOpen ? Colors.green : Colors.grey,
              radius: 6,
            ),
            const SizedBox(width: 12),

            // 📝 Shop Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shopName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Employees: $employees",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Orders: $orderCount", // ✅ Show order count
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),

            // ✅ Actions
            Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.qr_code_scanner,
                    color: Colors.deepPurple,
                  ),
                  tooltip: 'Check-In / Check-Out',
                  onPressed: onCheckIn,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
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
          ],
        ),
      ),
    );
  }
}
