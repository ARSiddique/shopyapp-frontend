import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';
import 'add_sale_screen.dart';

class ShopSelectionScreen extends StatelessWidget {
  const ShopSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final shops = appData.shops.where((shop) {
      final assignedShopIds = (appData.loggedInUser?['assignedShops'] ?? [])
          .cast<String>();
      return assignedShopIds.contains(shop['id']);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Shop'),
        automaticallyImplyLeading: false,
      ),
      body: shops.isEmpty
          ? const Center(child: Text('No shop assigned.'))
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: isWide
                      ? GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          children: shops
                              .map((shop) => _buildShopCard(context, shop))
                              .toList(),
                        )
                      : ListView.builder(
                          itemCount: shops.length,
                          itemBuilder: (_, index) =>
                              _buildShopCard(context, shops[index]),
                        ),
                );
              },
            ),
    );
  }

  Widget _buildShopCard(BuildContext context, Map<String, dynamic> shop) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => AddSaleScreen(selectedShopId: shop['id']),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.store,
                size: 40,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 10),
              Text(
                shop['name'] ?? 'Unnamed Shop',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                shop['location'] ?? '',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
