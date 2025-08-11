import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';
import '../screens/splash_screen.dart';

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
    Future.microtask(() async {
      final app = Provider.of<AppDataProvider>(context, listen: false);
      if (app.shops.isEmpty) {
        setState(() => _loading = true);
        await app.fetchShops();
        setState(() => _loading = false);
      }
    });
  }

  Future<void> _refresh() async {
    final app = Provider.of<AppDataProvider>(context, listen: false);
    await app.fetchShops();
  }

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppDataProvider>(context);
    final user = app.loggedInUser ?? {};
    final name = (user['name'] ?? 'Unknown').toString();
    final role = (user['role'] ?? '').toString();
    final assignedShops =
        (user['assignedShops'] as List? ?? []).map((e) => e.toString()).toList();

    return Scaffold(
    appBar: AppBar(
  centerTitle: false, // ✅ left aligned
  titleSpacing: 8,    // thora sa left padding
  title: Row(
    children: [
      Flexible(
        child: Text(
          '${name.trim().isEmpty ? 'Unknown' : name.trim()} | ${role.toString().toUpperCase()}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis, // ✅ responsive truncation
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    ],
  ),
actions: [
  IconButton(
    tooltip: 'Logout',
    icon: const Icon(Icons.logout),
    onPressed: () async {
      final confirm = await showDialog<bool>(
        context: context,
        barrierDismissible: false, // accidental dismiss na ho
        builder: (ctx) => AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Logout')),
          ],
        ),
      );

      if (confirm != true) return;

      await app.logout();           // <-- Provider logout (clears session + notifies)
      if (!mounted) return;

      // ✅ Purani stack hatao aur Splash/Login dikhao
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashScreen()), // ya LoginScreen()
        (route) => false,
      );
    },
  ),
],

),


      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: assignedShops.isEmpty
                  ? ListView( // RefreshIndicator needs scrollable
                      children: const [
                        SizedBox(height: 120),
                        Center(
                          child: Text(
                            'Shop Not Assigned',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: assignedShops.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final shopName = assignedShops[i];

                        // shops collection se id nikaal lo (name match)
                        final shop = app.shops.firstWhere(
                          (s) => (s['name'] ?? '') == shopName,
                          orElse: () => {},
                        );
                        final shopId = (shop['id'] ?? shopName).toString();

                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Theme.of(context)
                                  .dividerColor
                                  .withOpacity(0.4),
                            ),
                          ),
                          child: ListTile(
                            title: Text(shopName),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              app.setSelectedShop(shopId, shopName);

                              // 👉 TODO: yahan apni Add Sale / Home route pe redirect karo:
                              // Navigator.pushReplacement(
                              //   context,
                              //   MaterialPageRoute(
                              //     builder: (_) => AddSaleScreen(selectedShopName: shopName),
                              //   ),
                              // );
                            },
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
