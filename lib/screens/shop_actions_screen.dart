import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';
import 'add_sale_screen.dart';
import 'transactions_screen.dart';
import 'transaction_report_screen.dart';

class ShopActionsScreen extends StatelessWidget {
  final String shopName;
  const ShopActionsScreen({super.key, required this.shopName});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();
    final isEmployee = app.isEmployee; // role check
    final cols = MediaQuery.of(context).size.width >= 900 ? 3 : 2;

    return Scaffold(
      appBar: AppBar(title: Text('Shop: $shopName')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: cols,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.2,
          children: [
            _Tile(
              label: 'Daily Sale',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AddSaleScreen(shopName: shopName)),
              ),
            ),
            _Tile(
              label: 'Transaction',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TransactionsScreen(shopName: shopName)),
              ),
            ),
            if (!isEmployee)
              _Tile(
                label: 'Transaction History',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TransactionReportScreen(shopName: shopName)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _Tile({required this.label, required this.onTap}); // 🔧 removed super.key

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Center(
          child: Text(
            label,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
