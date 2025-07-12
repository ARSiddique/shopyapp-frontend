import 'package:flutter/material.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String selectedFilter = 'Daily';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sales Reports"),
        backgroundColor: Colors.deepPurple,
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔘 Filter buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: ['Daily', 'Weekly', 'Monthly'].map((filter) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: selectedFilter == filter,
                    onSelected: (selected) {
                      setState(() => selectedFilter = filter);
                    },
                    selectedColor: Colors.deepPurple,
                    backgroundColor: Colors.grey[200],
                    labelStyle: TextStyle(
                      color: selectedFilter == filter
                          ? Colors.white
                          : Colors.black,
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // 📊 Totals by payment type
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: const [
                _ReportCard(
                  label: "Cash",
                  amount: "Rs. 5,000",
                  color: Colors.green,
                ),
                _ReportCard(
                  label: "Card",
                  amount: "Rs. 3,200",
                  color: Colors.orange,
                ),
                _ReportCard(
                  label: "Venmo",
                  amount: "Rs. 1,100",
                  color: Colors.blue,
                ),
              ],
            ),

            const SizedBox(height: 24),

            const Text(
              "Recent Entries",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: ListView(
                children: const [
                  _SaleEntryTile(
                    shop: "New York",
                    date: "July 6",
                    total: "Rs. 1,200",
                  ),
                  _SaleEntryTile(
                    shop: "Texas",
                    date: "July 6",
                    total: "Rs. 900",
                  ),
                  _SaleEntryTile(
                    shop: "Chicago",
                    date: "July 6",
                    total: "Rs. 2,300",
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;

  const _ReportCard({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withOpacity(0.1),
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(amount, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _SaleEntryTile extends StatelessWidget {
  final String shop;
  final String date;
  final String total;

  const _SaleEntryTile({
    required this.shop,
    required this.date,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.storefront),
      title: Text(shop),
      subtitle: Text("Date: $date"),
      trailing: Text(
        total,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
