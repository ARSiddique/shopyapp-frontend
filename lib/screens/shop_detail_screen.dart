import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

class ShopDetailScreen extends StatelessWidget {
  final String shopName;
  final bool isOpen;

  const ShopDetailScreen({
    super.key,
    required this.shopName,
    required this.isOpen,
  });

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);

    // Get employees from this shop
    final shop = appData.shops.firstWhere(
      (s) => s['name'] == shopName,
      orElse: () => {},
    );
    final List employeeList = shop['employees'] ?? [];

    final orderCount = appData.orders
        .where((order) => order['shop'] == shopName)
        .length;

    return Scaffold(
      appBar: AppBar(title: Text(shopName), backgroundColor: Colors.deepPurple),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              shopName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text("Total Employees: ${employeeList.length}"),
            const SizedBox(height: 10),
            Text("Orders: $orderCount"),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text(
                  "Status: ",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Chip(
                  label: Text(isOpen ? "Open" : "Closed"),
                  backgroundColor: isOpen ? Colors.green : Colors.red,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              "More details like expenses, check-ins, and history will appear here soon.",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
