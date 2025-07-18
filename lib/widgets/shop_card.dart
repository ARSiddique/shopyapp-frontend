import 'package:flutter/material.dart';

class ShopCard extends StatelessWidget {
  final String shopName;
  final int employeeCount;
  final int orderCount;
  final bool isOpen;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool showDelete;

  const ShopCard({
    super.key,
    required this.shopName,
    required this.employeeCount,
    required this.orderCount,
    required this.isOpen,
    this.onTap,
    this.onDelete,
    this.showDelete = false,
  });

  @override
  Widget build(BuildContext context) {
    // final theme = Theme.of(context);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        onTap: onTap,
        leading: Icon(Icons.store, color: isOpen ? Colors.green : Colors.red),
        title: Text(shopName),
        subtitle: Text('👥 $employeeCount | 📦 $orderCount'),
        trailing: showDelete
            ? IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: onDelete,
              )
            : null,
      ),
    );
  }
}
