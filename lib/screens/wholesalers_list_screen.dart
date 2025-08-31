import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';
import 'wholesaler_detail_screen.dart';

class WholesalersListScreen extends StatefulWidget {
  const WholesalersListScreen({super.key});
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

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();
    final list = app.wholesalers;

    return Scaffold(
      appBar: AppBar(title: const Text('Wholesalers')),
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
                    return ListTile(
                      leading: const Icon(Icons.store_mall_directory),
                      title: Text((w['name'] ?? 'Unnamed').toString()),
                      subtitle: Text((w['phone'] ?? '').toString()),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(context,
                          MaterialPageRoute(builder: (_) => WholesalerDetailScreen(wholesaler: w)));
                      },
                    );
                  },
                ),
    );
  }
}
