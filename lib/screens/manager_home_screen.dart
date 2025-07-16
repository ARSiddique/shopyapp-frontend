import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';
import '../widgets/shop_card.dart';
// import '../utils/logger.dart';
import 'manager_orders_screen.dart';
import 'shop_detail_screen.dart';

class ManagerHomeScreen extends StatelessWidget {
  const ManagerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final user = appData.loggedInUser ?? {};
    final shops = appData.shops;

    final userName = user['name'] ?? "Manager";
    final role = user['role']?.toUpperCase() ?? "MANAGER";

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(userName, style: const TextStyle(fontSize: 18)),
            Text(role, style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "All Shops Overview",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: shops.isEmpty
                  ? const Center(
                      child: Text(
                        "No shops available.",
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: shops.length,
                      itemBuilder: (_, index) {
                        final shop = shops[index];
                        final employeeList = List<String>.from(
                          shop['employees'] ?? [],
                        );
                        final orderCount = appData.orders
                            .where((o) => o['shop'] == shop['name'])
                            .length;

                        return ShopCard(
  shopName: shop['name'],
  employeeCount: shop['employees']?.length ?? 0,
  isOpen: shop['isOpen'],
  orderCount: orderCount,
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShopDetailScreen(
          shopName: shop['name'],
        ),
      ),
    );
  },
);

                      },
                    ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ManagerOrdersScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.receipt_long),
                label: const Text("Manage Orders"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
