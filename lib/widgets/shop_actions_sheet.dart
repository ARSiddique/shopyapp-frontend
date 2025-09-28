import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';
import '../screens/orders_screen.dart';
import '../screens/sales_screen.dart';
import '../screens/wholesalers_list_screen.dart';
import '../screens/add_order_screen.dart';

Future<void> showShopActions(BuildContext context, String shopName) async {
  final app = context.read<AppDataProvider>();
  final role = (app.loggedInUser?['role'] ?? '').toString().toLowerCase();

  await showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(height: 4, width: 40,
                decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 12),
              Text(shopName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10, runSpacing: 10, children: [

                  _ActionChip(
                    icon: Icons.add_shopping_cart, label: 'Add Order',
                    onTap: () async {
                      Navigator.pop(context);
                      await _startAddOrderFlow(context, shopName);
                    },
                  ),

                  _ActionChip(
                    icon: Icons.shopping_bag, label: 'View Orders',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen()));
                    },
                  ),

                  if (role == 'admin' || role == 'manager')
                    _ActionChip(
                      icon: Icons.person_add_alt_1, label: 'Add Wholesaler',
                      onTap: () async {
                        Navigator.pop(context);
                        await _showAddWholesalerDialog(context);
                      },
                    ),

                  _ActionChip(
                    icon: Icons.trending_up, label: 'Sales',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesScreen()));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    },
  );
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
      elevation: 1,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }
}

Future<void> _startAddOrderFlow(BuildContext context, String shopName) async {
  // pick wholesaler using picker-mode screen
  final selected = await Navigator.push<String>(
    context,
    MaterialPageRoute(builder: (_) => const WholesalersListScreen(selectMode: true)),
  );
  if (!context.mounted || selected == null || selected.trim().isEmpty) return;

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

Future<void> _showAddWholesalerDialog(BuildContext context) async {
  final app = context.read<AppDataProvider>();
  final formKey = GlobalKey<FormState>();
  String name = '', phone = '', address = '';

  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Add Wholesaler'),
      content: Form(
        key: formKey,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(
            decoration: const InputDecoration(labelText: 'Name'),
            onChanged: (v) => name = v.trim(),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Phone'),
            onChanged: (v) => phone = v.trim(),
          ),
          const SizedBox(height: 8),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Address'),
            onChanged: (v) => address = v.trim(),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            if (!formKey.currentState!.validate()) return;
            final err = await app.addOrUpdateWholesaler(
              name: name, phone: phone, address: address,
            );
            if (!context.mounted) return;
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(err == null ? 'Wholesaler added' : 'Failed: $err')),
            );
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
