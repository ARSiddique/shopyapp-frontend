import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_data_provider.dart';
import 'shop_actions_screen.dart'; 
import 'login_screen.dart';

class ShopSelectionScreen extends StatefulWidget {
  const ShopSelectionScreen({super.key});

  @override
  State<ShopSelectionScreen> createState() => _ShopSelectionScreenState();
}

class _ShopSelectionScreenState extends State<ShopSelectionScreen> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // ✅ Avoid using BuildContext across async gaps
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final app = context.read<AppDataProvider>();
     setState(() => _loading = true);
     try {
      if (app.shops.isEmpty) {
         await app.fetchShops();
      }
     }finally{
      if(mounted){
        setState(() => _loading = false);
      }
     }
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();
    final me = app.loggedInUser ?? {};
    final role = (me['role'] ?? '').toString().toLowerCase();

    // all active shops
    final allActive = app.shops
        .where((s) => (s['isDeleted'] ?? false) != true)
        .map((s) => {
              'id': (s['id'] ?? '').toString(),
              'name': (s['name'] ?? '').toString(),
            })
        .where((s) => s['id']!.isNotEmpty && s['name']!.isNotEmpty)
        .toList()
      ..sort((a, b) => a['name']!.compareTo(b['name']!));

    // employee's assigned shops
    final assigned = (me['assignedShops'] as List? ?? [])
        .map((e) => e.toString().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();

    // visible list
    final isEmployee = role == 'employee';
   final visible = isEmployee
        ? allActive
        .where((s) => assigned.contains(s['name']!.toLowerCase()))
        .toList()
        : allActive;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Shop'),
         leading: Navigator.of(context).canPop() ? const BackButton() : null,
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: _confirmLogout,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
         : RefreshIndicator(
              onRefresh: () async => context.read<AppDataProvider>().fetchShops(),
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: visible.isEmpty
                  ? _emptyState(isEmployee: isEmployee)
                  : ListView.separated(
                      itemCount: visible.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final shop = visible[i];
                        return _ShopTile(
                          name: shop['name']!,
                          onTap: () => _selectShop(shop['id']!, shop['name']!),
                        );
                      },
                    ),
              ),
         
            ),
    );
  }

  Widget _emptyState({required bool isEmployee}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.store_outlined, size: 56, color: Colors.grey),
          const SizedBox(height: 10),
          Text(
            isEmployee
                ? 'No shop assigned to your account.'
                : 'No active shops found.',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            isEmployee
                ? 'Ask your admin/manager to assign shops.'
                : 'Add a shop or unhide deleted shops.',
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _selectShop(String id, String name) async {
    // ✅ pre-capture
    final app = context.read<AppDataProvider>();
    final navigator = Navigator.of(context);

    // save selection (if other parts use it)
    app.setSelectedShop(id, name);

    // ✅ open ShopActionsScreen for this shop
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => ShopActionsScreen(shopName: name),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    // ✅ pre-capture
    final navigator = Navigator.of(context);
    final app = context.read<AppDataProvider>();

    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Logout?'),
            content:
                const Text('You will be signed out and returned to the login screen.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Logout'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    await app.logout();
    if (!mounted) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }
}

class _ShopTile extends StatelessWidget {
  final String name;
  final VoidCallback onTap;

  const _ShopTile({
    required this.name,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
        ),
      ),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.store)),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
