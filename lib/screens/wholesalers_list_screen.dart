// lib/screens/wholesalers_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';
import 'wholesaler_detail_screen.dart';

class WholesalersListScreen extends StatefulWidget {
  const WholesalersListScreen({super.key, this.selectMode = false});
  final bool selectMode;

  @override
  State<WholesalersListScreen> createState() => _WholesalersListScreenState();
}

class _WholesalersListScreenState extends State<WholesalersListScreen> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      setState(() => _loading = true);
      await context.read<AppDataProvider>().fetchWholesalers();
      if (mounted) setState(() => _loading = false);
    });
  }

  Future<void> _addInline() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    final app = context.read<AppDataProvider>();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Wholesaler'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
            TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: 'Address')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final err = await app.addOrUpdateWholesaler(
                name: nameCtrl.text,
                phone: phoneCtrl.text,
                address: addrCtrl.text,
              );
              if (!mounted) return;
              Navigator.pop(context);

              if (err == null) {
                await app.fetchWholesalers();
                if (widget.selectMode) {
                  Navigator.pop(context, nameCtrl.text.trim());
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Wholesaler added')),
                  );
                  setState(() {});
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed: $err')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();
    final list = app.wholesalers;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectMode ? 'Select Wholesaler' : 'Wholesalers'),
        actions: [
          if (widget.selectMode)
            IconButton(
              tooltip: 'Add',
              icon: const Icon(Icons.add),
              onPressed: _addInline,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : list.isEmpty
              ? const Center(child: Text('No wholesalers found'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final w = list[i];
                    final name = (w['name'] ?? 'Unnamed').toString();
                    return ListTile(
                      leading: const Icon(Icons.store_mall_directory),
                      title: Text(name),
                      subtitle: Text((w['phone'] ?? '').toString()),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        if (widget.selectMode) {
                          Navigator.pop(context, name);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => WholesalerDetailScreen(wholesaler: w),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
    );
  }
}
