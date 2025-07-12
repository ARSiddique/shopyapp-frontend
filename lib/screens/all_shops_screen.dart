import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

class AllShopsScreen extends StatelessWidget {
  const AllShopsScreen({super.key});

  void _confirmDelete(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Shop"),
        content: const Text("Are you sure you want to delete this shop?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Provider.of<AppDataProvider>(
                context,
                listen: false,
              ).deleteShop(index);
              Navigator.pop(context);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shopData = Provider.of<AppDataProvider>(context);
    final shops = shopData.shops;

    return Scaffold(
      appBar: AppBar(
        title: const Text("All Shops"),
        backgroundColor: Colors.deepPurple,
      ),
      body: shops.isEmpty
          ? const Center(child: Text("No shops added yet."))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemCount: shops.length,
              itemBuilder: (context, index) {
                final shop = shops[index];
                return ListTile(
                  leading: const Icon(Icons.store),
                  title: Text(shop['name'] ?? "Unnamed Shop"),
                  subtitle: Text("Employees: ${shop['employees']}"),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _confirmDelete(context, index),
                  ),
                );
              },
            ),
    );
  }
}
