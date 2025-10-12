import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_data_provider.dart';
import 'shop_actions_screen.dart';
import 'add_sale_screen.dart';
import 'transactions_screen.dart';
import 'login_screen.dart';
import 'cash_collect_screen.dart';
import 'sales_screen.dart';

enum NextAction { actions, addSale, transaction, cashCollect, sales }

class ShopSelectionScreen extends StatefulWidget {
  const ShopSelectionScreen({super.key, this.next = NextAction.actions});

  /// After selecting a shop, where to go?
  /// - actions: hub
  /// - addSale: AddSaleScreen directly
  /// - transaction: TransactionsScreen directly
  /// - cashCollect: CashCollectScreen with selected shop
  /// - sales: SalesScreen with selected shop (or ALL)
  final NextAction next;

  @override
  State<ShopSelectionScreen> createState() => _ShopSelectionScreenState();
}

class _ShopSelectionScreenState extends State<ShopSelectionScreen> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final app = context.read<AppDataProvider>();
      setState(() => _loading = true);
      try {
        if (app.shops.isEmpty) {
          await app.fetchShops();
        }
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();
    final me = app.loggedInUser ?? {};
    final role = (me['role'] ?? '').toString().toLowerCase();

    final allActive = app.shops
        .where((s) => (s['isDeleted'] ?? false) != true)
        .map((s) => {
              'id': (s['id'] ?? '').toString(),
              'name': (s['name'] ?? '').toString(),
            })
        .where((s) => s['id']!.isNotEmpty && s['name']!.isNotEmpty)
        .toList()
      ..sort((a, b) => a['name']!.compareTo(b['name']!));

    final assigned = (me['assignedShops'] as List? ?? [])
        .map((e) => e.toString().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();

    final isEmployee = role == 'employee';
    final visibleBase = isEmployee
        ? allActive.where((s) => assigned.contains(s['name']!.toLowerCase())).toList()
        : allActive;

    // Inject "All Shops" at top for Admin/Manager when navigating to Sales
    final showAllShopsOption = !isEmployee && widget.next == NextAction.sales && visibleBase.isNotEmpty;
    final visible = showAllShopsOption
        ? [
            {'id': 'ALL', 'name': 'All Shops'},
            ...visibleBase,
          ]
        : visibleBase;

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
                          final isAll = shop['id'] == 'ALL';
                          return _ShopTile(
                            name: shop['name']!,
                            leadingIcon: isAll ? Icons.all_inclusive : Icons.store,
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
            style: const TextStyle(fontWeight: FontWeight.w600)),
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
    final app = context.read<AppDataProvider>();
    final navigator = Navigator.of(context);

    // Save selection (including ALL sentinel so SalesScreen can read it if needed)
    app.setSelectedShop(id, name);

    switch (widget.next) {
      case NextAction.addSale:
        await navigator.push(MaterialPageRoute(builder: (_) => AddSaleScreen(shopName: name)));
        break;

      case NextAction.transaction:
        await navigator.push(MaterialPageRoute(builder: (_) => TransactionsScreen(shopName: name)));
        break;

      case NextAction.cashCollect:
        await navigator.push(MaterialPageRoute(builder: (_) => CashCollectScreen(initialShopName: name)));
        break;

      case NextAction.sales:
        // For ALL, we pass a sentinel that SalesScreen can interpret as "show all"
        final initial = id == 'ALL' ? 'ALL' : name;
        await navigator.push(MaterialPageRoute(builder: (_) => SalesScreen(initialShopName: initial)));
        break;

      case NextAction.actions:
      default:
        await navigator.push(MaterialPageRoute(builder: (_) => ShopActionsScreen(shopName: name)));
        break;
    }
  }

  Future<void> _confirmLogout() async {
    final navigator = Navigator.of(context);
    final app = context.read<AppDataProvider>();

    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Logout?'),
            content: const Text('You will be signed out and returned to the login screen.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Logout')),
            ],
          ),
        ) ?? false;

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
  final IconData leadingIcon;
  final VoidCallback onTap;

  const _ShopTile({
    required this.name,
    required this.leadingIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isAll = name.toLowerCase().contains('all shop');
    return Card(
      elevation: 0,
      color: isAll ? Theme.of(context).colorScheme.surfaceContainerHighest : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
      ),
      child: ListTile(
        leading: CircleAvatar(child: Icon(leadingIcon)),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
