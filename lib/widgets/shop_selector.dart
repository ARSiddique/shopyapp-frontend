import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

Future<void> showShopSelector(BuildContext context) async {
  final app = context.read<AppDataProvider>();
  final me = app.loggedInUser ?? {};
  final role = (me['role'] ?? 'employee').toString().toLowerCase();
  final isEmployee = role == 'employee';

  final all = isEmployee
      ? (me['assignedShops'] as List? ?? const [])
          .map((e) => e.toString())
          .where((s) => s.isNotEmpty)
          .toList()
      : app.shops
          .where((s) => (s['isDeleted'] ?? false) != true)
          .map((s) => (s['name'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .toList()
        ..sort();

  final selected = app.selectedShopName;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(height: 4, width: 40, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 10),
              const Text('Select Shop', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              if (all.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No shops available'),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: all.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final name = all[i];
                      final isSel = name == selected;
                      return ListTile(
                        title: Text(name),
                        leading: isSel
                            ? const Icon(Icons.radio_button_checked, color: Colors.deepPurple)
                            : const Icon(Icons.radio_button_off),
                        onTap: () {
                          app.setSelectedShop(app.selectedShopId ?? name, name);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
