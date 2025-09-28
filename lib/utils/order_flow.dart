import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/app_data_provider.dart';
import '../screens/add_order_screen.dart';
import '../screens/wholesalers_list_screen.dart';

/// One-tap "Add Order" flow used from Dashboard etc.
Future<void> startAddOrderFlow(BuildContext context) async {
  final app = context.read<AppDataProvider>();

  // ensure shop selected (for admin/manager picker elsewhere ho sakta)
  if ((app.selectedShopName ?? '').isEmpty) {
    // try best: if exactly 1 shop, auto-pick it
    final shops = app.shops.where((s) => (s['isDeleted'] ?? false) != true).toList();
    if (shops.length == 1) {
      final s = shops.first;
      app.setSelectedShop((s['id'] ?? s['docId'] ?? '').toString(), (s['name'] ?? '').toString());
    } else {
      // fall back: simple sheet to pick
      final chosen = await showModalBottomSheet<Map<String, String>>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: shops.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final s = shops[i];
              final id = (s['id'] ?? s['docId'] ?? '').toString();
              final name = (s['name'] ?? 'Unnamed').toString();
              return ListTile(
                leading: const Icon(Icons.store),
                title: Text(name),
                onTap: () => Navigator.pop(context, {'id': id, 'name': name}),
              );
            },
          ),
        ),
      );
      if (chosen == null) return;
      app.setSelectedShop(chosen['id']!, chosen['name']!);
    }
  }
  if (!context.mounted) return;

  final shopName = app.selectedShopName ?? '';
  if (shopName.isEmpty) return;

  // ensure wholesalers
  if (app.wholesalers.isEmpty) {
    await app.fetchWholesalers();
    if (!context.mounted) return;
  }

  // pick wholesaler
  final selectedWh = await Navigator.push<String>(
    context,
    MaterialPageRoute(builder: (_) => const WholesalersListScreen(selectMode: true)),
  );
  if (!context.mounted || selectedWh == null || selectedWh.trim().isEmpty) return;

  // prevent duplicate: one shop + one wholesaler + one day
  final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final already = app.orders.any((o) =>
      (o['shopName'] ?? o['shop']) == shopName &&
      (o['wholesalerName'] ?? o['wholesaler'] ?? '') == selectedWh &&
      (o['dayKey'] ?? '') == todayKey);
  if (already) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Today\'s order already exists for this wholesaler.')),
    );
    return;
  }

  // go to AddOrder
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AddOrderScreen(
        shopName: shopName,
        wholesalerName: selectedWh.trim(),
      ),
    ),
  );
}
