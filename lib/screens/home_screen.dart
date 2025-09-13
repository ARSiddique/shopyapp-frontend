import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/app_data_provider.dart';
import '../widgets/summary_card.dart';
import '../widgets/shop_card.dart';
import '../screens/add_sale_screen.dart';
import '../screens/add_shop_screen.dart';
import '../screens/orders_screen.dart';
import '../screens/sales_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/login_screen.dart';
import '../screens/all_shops_screen.dart';
import '../screens/employees_overview_screen.dart';
import '../screens/add_order_screen.dart';
import '../screens/add_expense_screen.dart';
import '../screens/expenses_screen.dart';
import '../screens/add_payment_screen.dart';
import '../screens/payments_screen.dart';
import '../utils/order_flow.dart'; // ⬅️ add this



void showPlatformLogoutDialog(BuildContext context) {
  final appData = Provider.of<AppDataProvider>(context, listen: false);
  if (Platform.isIOS) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("Logout?"),
        content: const Text("Are you sure you want to logout from Shopy App?"),
        actions: [
          CupertinoDialogAction(
            child: const Text("Cancel"),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text("Logout"),
            onPressed: () {
              Navigator.of(ctx).pop();
              appData.logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
          ),
        ],
      ),
    );
  } else {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text("Logout"),
            onPressed: () {
              Navigator.of(ctx).pop();
              appData.logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}

Future<bool> showPlatformExitDialog(BuildContext context) async {
  final choice = await (Platform.isIOS
      ? showCupertinoDialog<bool>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Exit App?'),
            content: const Text('Do you want to quit the app?'),
            actions: [
              CupertinoDialogAction(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(ctx).pop(false),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                child: const Text('Quit'),
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
        )
      : showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Exit App'),
            content: const Text('Do you want to quit the app?'),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(ctx).pop(false),
              ),
              TextButton(
                child: const Text('Quit'),
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
        ));
  return choice ?? false;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  void _onLogoutTap() => showPlatformLogoutDialog(context);

  @override
  void initState() {
    super.initState();
    final appData = Provider.of<AppDataProvider>(context, listen: false);
    appData.startFirebaseListeners();
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final user = appData.loggedInUser ?? {};
    final role = (user['role'] ?? 'employee').toString().toLowerCase();

    final pages = <Widget>[
      const HomeDashboard(),
      const ProfileScreen(),
      if (role == 'admin' || role == 'manager' || role == 'employee')
        const OrdersScreen(),
      if (role == 'admin' || role == 'manager') const SalesScreen(),
    ];

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final shouldExit = await showPlatformExitDialog(context);
          if (shouldExit) exit(0);
        }
      },
      child: Scaffold(
        appBar: _selectedIndex == 0
            ? AppBar(
                backgroundColor: Colors.deepPurple,
                title: Text(
                  '${user['name'] ?? ''} (${role.isNotEmpty ? role[0].toUpperCase() + role.substring(1) : 'Employee'})',
                  style: const TextStyle(color: Colors.white),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.red),
                    tooltip: 'Logout',
                    onPressed: _onLogoutTap,
                  ),
                ],
              )
            : null,
        body: pages[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() => _selectedIndex = index);
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

class HomeDashboard extends StatelessWidget {
  const HomeDashboard({super.key});

  // ================== Helpers (inside class) ==================

  // Shop selector (bottom sheet)
  void showShopSelector(BuildContext context) {
    final app = Provider.of<AppDataProvider>(context, listen: false);
    final user = app.loggedInUser ?? {};
    final role = (user['role'] ?? 'employee').toString().toLowerCase();
    final isEmployee = role == 'employee';

    // Visible shops list (same logic as list below)
    final assigned = (user['assignedShops'] as List? ?? const [])
        .map((e) => e.toString().trim().toLowerCase())
        .toList();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Consumer<AppDataProvider>(
          builder: (_, app, __) {
            final all = app.shops
                .where((s) => (s['isDeleted'] ?? false) != true)
                .toList();
            final visible = isEmployee
                ? all.where((s) {
                    final nm = (s['name'] ?? '').toString().trim().toLowerCase();
                    return assigned.contains(nm);
                  }).toList()
                : all;

            if (visible.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No shops to select.'),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: visible.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final s = visible[i];
                final id = (s['id'] ?? '').toString();
                final name = (s['name'] ?? 'Unnamed').toString();
                return ListTile(
                  leading: const Icon(Icons.store),
                  title: Text(name),
                  onTap: () {
                    Navigator.pop(context);
                    app.setSelectedShop(id, name);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  // Shop actions (bottom sheet)
void showShopActions(BuildContext context, String shopName) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            shopName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          // Orders / Sales
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Add Order'),
           onTap: () async {
  Navigator.pop(context);
  await startAddOrderFlow(context);
},
          ),
          ListTile(
            leading: const Icon(Icons.trending_up),
            title: const Text('Add Sale'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddSaleScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.shopping_bag),
            title: const Text('View Orders'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OrdersScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.query_stats),
            title: const Text('View Sales'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SalesScreen()),
              );
            },
          ),

          const Divider(height: 1),

          // Expenses
          ListTile(
            leading: const Icon(Icons.money_off_csred),
            title: const Text('Add Expense'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt),
            title: const Text('View Expenses'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExpensesScreen()),
              );
            },
          ),

          // Payments
          ListTile(
            leading: const Icon(Icons.payments),
            title: const Text('Add Payment'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddPaymentScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.list_alt),
            title: const Text('View Payments'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaymentsScreen()),
              );
            },
          ),

          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}



  // ================== UI ==================

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final user = appData.loggedInUser ?? {};
    final role = (user['role'] ?? 'employee').toString().toLowerCase();
    final isEmployee = role == 'employee';
    final employeeName = (user['name'] ?? '').toString();

    // Employee orders → provider field: createdByName
    final employeeOrders = appData.orders
        .where((o) => (o['createdByName'] ?? o['employee']) == employeeName)
        .toList();

    // Aaj ki sales (employee view: sirf assigned shops)
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final assignedShops = (user['assignedShops'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();

    final todayShopSales = appData.sales.where((sale) {
      final saleDate = sale['saleDate'];
      final shopName = sale['shop'];
      return saleDate == todayStr &&
          (isEmployee ? assignedShops.contains(shopName) : true);
    }).toList();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('shops').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final shops = snapshot.data?.docs ?? [];
        final visibleShops = (role == 'admin' || role == 'manager')
            ? shops.where((doc) => (doc['isDeleted'] ?? false) != true).toList()
            : shops.where((doc) {
                final shopName =
                    (doc['name'] ?? '').toString().trim().toLowerCase();
                final my = assignedShops.map((s) => s.trim().toLowerCase());
                return my.contains(shopName) &&
                    (doc['isDeleted'] ?? false) != true;
              }).toList();

        final selectedShop = appData.selectedShopName;

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selected shop chip + change
                if (selectedShop != null && selectedShop.isNotEmpty) ...[
                  Row(
                    children: [
                      Chip(
                        avatar: const Icon(Icons.store, size: 16),
                        label: Text(selectedShop),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => showShopSelector(context),
                        icon: const Icon(Icons.swap_horiz),
                        label: const Text('Change'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ] else ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => showShopSelector(context),
                      icon: const Icon(Icons.store_mall_directory),
                      label: const Text('Select shop'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                const Text(
                  'Dashboard Overview',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.2,
                  children: [
                    SummaryCard(
                      icon: Icons.shopping_bag,
                      title: 'Orders',
                      value: isEmployee
                          ? employeeOrders.length.toString()
                          : appData.orders.length.toString(),
                      color: Colors.deepPurple,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const OrdersScreen(),
                          ),
                        );
                      },
                    ),
                    SummaryCard(
                      icon: Icons.trending_up,
                      title: 'Sales',
                      value: isEmployee
                          ? todayShopSales.length.toString()
                          : appData.sales.length.toString(),
                      color: Colors.teal,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => isEmployee
                                ? const AddSaleScreen()
                                : const SalesScreen(),
                          ),
                        );
                      },
                    ),
                    if (!isEmployee)
                      SummaryCard(
                        icon: Icons.store,
                        title: 'Shops',
                        value: appData.shops.length.toString(),
                        color: Colors.orange,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AllShopsScreen(),
                            ),
                          );
                        },
                      ),
                    if (!isEmployee)
                      SummaryCard(
                        icon: Icons.people,
                        title: 'Employees',
                        value: appData.employees.length.toString(),
                        color: Colors.blue,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const EmployeesOverviewScreen(),
                            ),
                          );
                        },
                      ),
                  ],
                ),

                const SizedBox(height: 32),
                const Text(
                  "Shops Overview",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                visibleShops.isEmpty
                    ? Column(
                        children: [
                          const Icon(Icons.store_mall_directory,
                              size: 64, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text("No shops added yet.",
                              style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 10),
                          if (!isEmployee)
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text("Add Your First Shop"),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AddShopScreen(),
                                  ),
                                );
                              },
                            ),
                        ],
                      )
                    : Column(
                        children: [
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount:
                                visibleShops.length >= 3 ? 3 : visibleShops.length,
                            itemBuilder: (_, index) {
                              final shop = visibleShops[index];
                              final data = shop.data() as Map<String, dynamic>;
                              final shopName =
                                  (data['name'] ?? 'Unnamed').toString();
                              final employees =
                                  (data['employees'] as List?) ?? const [];

                              // Orders count per shop
                              final countForShop = appData.orders
                                  .where((o) =>
                                      (o['shopName'] ?? o['shop']) == shopName)
                                  .length;

                              return ShopCard(
                                shopName: shopName,
                                employeeCount: employees.length,
                                isOpen: data['isOpen'] ?? false,
                                orderCount: countForShop,
                                onTap: () {
                                  // Save selected + show actions
                                  appData.setSelectedShop(shop.id, shopName);
                                  showShopActions(context, shopName);
                                },
                              );
                            },
                          ),
                          if (visibleShops.length > 3)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const AllShopsScreen(),
                                    ),
                                  );
                                },
                                child: const Text("See All Shops →"),
                              ),
                            ),
                        ],
                      ),
              ],
            ),
          ),
        );
      },
    );
  }
}
