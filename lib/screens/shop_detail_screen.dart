import 'package:flutter/material.dart';

class ShopDetailScreen extends StatelessWidget {
  final String shopName;
  final int employees;
  final bool isOpen;

  const ShopDetailScreen({
    super.key,
    required this.shopName,
    required this.employees,
    required this.isOpen,
  });

  @override
  Widget build(BuildContext context) {
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
            Text("Employees: $employees"),
            const SizedBox(height: 10),
            Row(
              children: [
                Text("Status: ", style: TextStyle(fontWeight: FontWeight.bold)),
                Chip(
                  label: Text(isOpen ? "Open" : "Closed"),
                  backgroundColor: isOpen ? Colors.green : Colors.red,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              "This is just a placeholder.\nWe’ll add more data like expenses, check-ins, orders, etc. here.",
            ),
          ],
        ),
      ),
    );
  }
}
