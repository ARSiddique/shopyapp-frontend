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
import '../screens/shop_detail_screen.dart';
import '../screens/employees_overview_screen.dart';
// import 'package:intl/intl.dart';

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
    final role = user['role'] ?? 'employee';

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
                  '${user['name']} (${role[0].toUpperCase()}${role.substring(1)})',
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
            setState(() {
              _selectedIndex = index;
            });
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

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final user = appData.loggedInUser ?? {};
    final role = user['role']?.toLowerCase() ?? 'employee';
    final isEmployee = role == 'employee';
    final employeeName = user['name'] ?? '';

    // For Orders & Sales by employee
    final employeeOrders = appData.orders
        .where((order) => order['employee'] == employeeName)
        .toList();
    // ✅ Add this block here:
    // final todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    // final assignedShops = (user['assignedShops'] ?? [])
    //     .map<String>((s) => s.toString())
    //     .toList();
    // final todayShopSales = appData.sales.where((sale) {
    //   final saleDate = sale['saleDate'];
    //   final shopName = sale['shop'];
    //   return saleDate == todayDate && assignedShops.contains(shopName);
    // }).toList();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('shops').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final shops = snapshot.data?.docs ?? [];
        final assignedShops = (user['assignedShops'] ?? [])
            .map<String>((s) => s.toString())
            .toList();

        debugPrint('ROLE: $role');
        debugPrint('Assigned Shops: $assignedShops');
        for (var doc in shops) {
          debugPrint('Shop: ${doc['name']}');
        }

        final visibleShops = (role == 'admin' || role == 'manager')
            ? shops.where((doc) => doc['isDeleted'] != true).toList()
            : shops.where((doc) {
                final shopName = doc['name']?.toString().trim().toLowerCase();
                return assignedShops
                        .map((s) => s.trim().toLowerCase())
                        .contains(shopName) &&
                    doc['isDeleted'] != true;
              }).toList();
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      // value: isEmployee
                      //     ? employeeOrders.length.toString()
                      //     : appData.orders.length.toString(),
                      value: ' ',
                      color: Colors.deepPurple,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OrdersScreen(
                              filteredOrders: isEmployee
                                  ? employeeOrders
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                    SummaryCard(
                      icon: Icons.trending_up,
                      title: 'Sales',
                      // value: isEmployee
                      //     ? todayShopSales.length.toString()
                      //     : appData.sales.length.toString(),
                      value: ' ',
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
                        // value: appData.shops.length.toString(),
                        value: ' ',
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
                        // value: appData.employees.length.toString(),
                        value: ' ',
                        color: Colors.blue,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const EmployeesOverviewScreen(),
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
                          const Icon(
                            Icons.store_mall_directory,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "No shops added yet.",
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 10),
                          if (role == 'admin' || role == 'manager')
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
                            itemCount: visibleShops.length >= 3
                                ? 3
                                : visibleShops.length,
                            itemBuilder: (_, index) {
                              final shop = visibleShops[index];
                              final data = shop.data() as Map<String, dynamic>;
                              final shopName = data['name'] ?? 'Unnamed';
                              final employees = data.containsKey('employees')
                                  ? data['employees']
                                  : [];

                              return ShopCard(
                                shopName: shopName,
                                employeeCount: employees.length,
                                isOpen: data['isOpen'] ?? false,
                                orderCount: appData.orders
                                    .where((o) => o['shop'] == shopName)
                                    .length,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ShopDetailScreen(shopName: shopName),
                                    ),
                                  );
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
