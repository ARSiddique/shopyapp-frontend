import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final user = appData.loggedInUser;
    final role = user?['role'] ?? 'admin';
    final sales = appData.sales;

    // 🔒 Restrict Employee
    if (role == 'employee') {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Sales Summary"),
          backgroundColor: Colors.deepPurple,
        ),
        body: const Center(
          child: Text(
            "Access Denied.\nSales data is visible only to Manager and Admin.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red, fontSize: 16),
          ),
        ),
      );
    }

    double totalCash = 0;
    double totalCard = 0;
    double totalVenmo = 0;

    for (var sale in sales) {
      totalCash += sale['cash'] ?? 0;
      totalCard += sale['card'] ?? 0;
      totalVenmo += sale['venmo'] ?? 0;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Sales Summary"),
        backgroundColor: Colors.deepPurple,
      ),
      body: sales.isEmpty
          ? const Center(child: Text("No sales recorded yet."))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Total Summary",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text("Cash: Rs. ${totalCash.toStringAsFixed(0)}"),
                      Text("Card: Rs. ${totalCard.toStringAsFixed(0)}"),
                      Text("Venmo: Rs. ${totalVenmo.toStringAsFixed(0)}"),
                      const Divider(height: 32),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: sales.length,
                    itemBuilder: (context, index) {
                      final sale = sales[index];
                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const Icon(
                            Icons.attach_money,
                            color: Colors.teal,
                          ),
                          title: Text("Rs. ${sale['amount']}"),
                          subtitle: Text(
                            "Cash: Rs. ${sale['cash']}, Card: Rs. ${sale['card']}, Venmo: Rs. ${sale['venmo']}",
                          ),
                          trailing: Text(sale['date'] ?? ''),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
