// lib/utils/order_flow.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';
import '../screens/wholesalers_list_screen.dart';
import '../screens/add_order_screen.dart';

Future<void> startAddOrderFlow(BuildContext context) async {
  final app = context.read<AppDataProvider>();
  final shopName = app.selectedShopName ?? '';
  if (shopName.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please select a shop first.')),
    );
    return;
  }

  // 1) Wholesaler select
  final selected = await Navigator.push<String>(
    context,
    MaterialPageRoute(
      builder: (_) => const WholesalersListScreen(selectMode: true),
    ),
  );
  if (selected == null || selected.trim().isEmpty) return;

  // 2) Prefilled Add Order
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AddOrderScreen(
        shopName: shopName,
        wholesalerName: selected.trim(),
      ),
    ),
  );
}
