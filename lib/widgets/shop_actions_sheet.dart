import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';
import '../screens/add_order_screen.dart';
import '../screens/orders_screen.dart';
import '../screens/sales_screen.dart';

Future<void> showShopActions(BuildContext context, String shopName) async {
  final app = context.read<AppDataProvider>();

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
              Container(height: 4, width: 40, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 12),
              Text(shopName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _ActionChip(
                    icon: Icons.add_shopping_cart,
                    label: 'Add Order',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AddOrderScreen()));
                    },
                  ),
                  _ActionChip(
                    icon: Icons.shopping_bag,
                    label: 'View Orders',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen()));
                    },
                  ),
                  _ActionChip(
                    icon: Icons.trending_up,
                    label: 'Sales',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesScreen()));
                    },
                  ),
                  _ActionChip(
                    icon: Icons.lock_clock,
                    label: 'Close Day',
                    onTap: () async {
                      Navigator.pop(context);
                      final err = await app.postDailySaleFromTransactions(
                        shopName: shopName,
                        day: DateTime.now(),
                      );
                      // ignore: use_build_context_synchronously
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(err == null ? 'Day closed for $shopName' : 'Failed: $err')),
                      );
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
