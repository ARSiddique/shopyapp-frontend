import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';
import '../widgets/shop_card.dart';
import '../utils/logger.dart';
import '../screens/manager_orders_screen.dart';

class ManagerHomeScreen extends StatelessWidget {
  const ManagerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final user = appData.loggedInUser;
    final assignedShops = user?['assignedShops'] ?? [];

    final shops = appData.shops
        .where((shop) => assignedShops.contains(shop['name']))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Manager Dashboard"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Assigned Shops",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: shops.isEmpty
                  ? const Center(
                      child: Text(
                        "No shops assigned yet.",
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      itemCount: shops.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, index) {
                        final shop = shops[index];
                        final orderCount = appData.orders
                            .where((o) => o['shop'] == shop['name'])
                            .length;

                        return ShopCard(
                          shopName: shop['name'],
                          employees: shop['employees'],
                          isOpen: shop['isOpen'],
                          orderCount: orderCount,
                          onCheckIn: () =>
                              log.info("Manager checked in to ${shop['name']}"),
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
