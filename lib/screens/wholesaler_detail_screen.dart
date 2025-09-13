// lib/screens/wholesaler_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';
import 'add_order_screen.dart';

class WholesalerDetailScreen extends StatelessWidget {
  const WholesalerDetailScreen({super.key, required this.wholesaler});
  final Map<String, dynamic> wholesaler;

  @override
  Widget build(BuildContext context) {
    final name = (wholesaler['name'] ?? '').toString();
    final phone = (wholesaler['phone'] ?? '').toString();
    final address = (wholesaler['address'] ?? '').toString();

    final app = context.watch<AppDataProvider>();
    final shopName = app.selectedShopName ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(name.isEmpty ? 'Wholesaler' : name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.badge),
            title: Text(name.isEmpty ? '—' : name),
            subtitle: const Text('Name'),
          ),
          ListTile(
            leading: const Icon(Icons.phone),
            title: Text(phone.isEmpty ? '—' : phone),
            subtitle: const Text('Phone'),
          ),
          ListTile(
            leading: const Icon(Icons.place),
            title: Text(address.isEmpty ? '—' : address),
            subtitle: const Text('Address'),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.receipt_long),
            label: const Text('Add Order for this Wholesaler'),
            onPressed: () {
              if (shopName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select a shop first.')),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddOrderScreen(
                    shopName: shopName,             // ⬅️ prefilled
                    wholesalerName: name,           // ⬅️ prefilled
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
