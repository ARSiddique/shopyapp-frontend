// lib/screens/return_items_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

class ReturnItemsScreen extends StatefulWidget {
  const ReturnItemsScreen({super.key});
  @override
  State<ReturnItemsScreen> createState() => _ReturnItemsScreenState();
}

class _ReturnItemsScreenState extends State<ReturnItemsScreen> {
  String? _orderId; // pick from a filtered list (pending/received for my shop)
  final _noteCtrl = TextEditingController();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();
    final myShop = app.selectedShopName ?? '';
    final myOrders = app.orders.where((o) => (o['shopName'] ?? '') == myShop).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Return Items')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          DropdownButtonFormField<String>(
            value: _orderId,
            decoration: const InputDecoration(labelText: 'Select Order', border: OutlineInputBorder()),
            items: myOrders.map((o) {
              final w = (o['wholesalerName'] ?? '').toString();
              final id = (o['id'] ?? '').toString();
              return DropdownMenuItem(value: id, child: Text('$w • ${o['status'] ?? ''}'));
            }).toList(),
            onChanged: (v) => setState(() => _orderId = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Return note', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _busy || (_orderId ?? '').isEmpty
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      await context.read<AppDataProvider>().requestOrderReturn(_orderId!, note: _noteCtrl.text.trim());
                      if (!mounted) return;
                      setState(() => _busy = false);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Return requested')));
                      Navigator.pop(context);
                    },
              child: _busy ? const CircularProgressIndicator() : const Text('Submit Return'),
            ),
          ),
        ]),
      ),
    );
  }
}
