// lib/screens/shop_actions_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';
import 'add_sale_screen.dart';
import 'transactions_screen.dart';
import 'transaction_report_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart'; // 👈 NEW

class ShopActionsScreen extends StatelessWidget {
  final String shopName;
  const ShopActionsScreen({super.key, required this.shopName});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();

    // ✅ Teenon roles Daily Sale kar sakte hain
    final canPostDailySale = app.isEmployee || app.isAdmin || app.isManager;
    final isEmployee = app.isEmployee;
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
            // 🔓 show for all 3 roles
            if (canPostDailySale)
              _Tile(
                label: 'Daily Sale',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddSaleScreen(shopName: shopName),
                  ),
                ),
              ),

            _Tile(
              label: 'Transactions',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TransactionsScreen(shopName: shopName),
                ),
              ),
            ),

            _Tile(
              label: 'Orders',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OrdersScreen()),
              ),
            ),

            // History (report) admin/manager ko hi dikhayen
            if (!isEmployee)
              _Tile(
                label: 'Transaction History',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TransactionReportScreen(shopName: shopName),
                  ),
                ),
              ),

            // 👇 NEW: Employee-only Profile tile (logout option Profile screen par hai)
            if (isEmployee)
              _Tile(
                label: 'Profile',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
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

  const _Tile({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
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
