import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/app_data_provider.dart';
import '../widgets/summary_card.dart';
// import '../widgets/quick_action_button.dart';
import '../widgets/shop_card.dart';
// import '../screens/add_order_screen.dart';
import '../screens/add_sale_screen.dart';
// import '../screens/reports_screen.dart';
import '../screens/add_shop_screen.dart';
// import '../screens/add_employee_and_access_screen.dart';
import '../screens/orders_screen.dart';
import '../screens/sales_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/login_screen.dart';
import '../screens/all_shops_screen.dart';
import '../screens/shop_detail_screen.dart';
import '../screens/employees_overview_screen.dart';

/// Shows a confirmation dialog before logging out.
void showPlatformLogoutDialog(BuildContext context) {
  final appData = Provider.of<AppDataProvider>(context, listen: false);
  // final activeShops = appData.shops
  //     .where((shop) => shop['isDeleted'] != true)
  //     .toList();
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
  //  String _getAppBarTitle(int index, String name, String role) {
  //     switch (index) {
  //       case 0:
  //         return '$name (${role[0].toUpperCase()}${role.substring(1)})'; // Home
  //       case 1:
  //         return 'Orders';
  //       case 2:
  //         return 'Sales';
  //       case 3:
  //         return 'Profile & Settings';
  //       default:
  //         return '';
  //     }
  //   }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final user = appData.loggedInUser;
    final name = user?['name'] ?? 'User';
    final role = user?['role'];
    // final isEmployee = role == 'employee';
    // final employeeName = user?['name'];
    // final assignedShops = appData.shops.where((s) {
    //   final assignedList = s['assignedEmployees'] ?? [];
    //   return assignedList.any((e) => e['name'] == name);
    // }).toList();
    // final employeeOrders = appData.orders
    //     .where((o) => o['employee'] == name)
    //     .toList();
    // final employeeSales = appData.sales
    //     .where((s) => s['submittedBy'] == name)
    //     .toList();
    final pages = <Widget>[
      const HomeDashboard(),
      const ProfileScreen(),
      if (role == 'admin' || role == 'manager' || role == 'employee')
        const OrdersScreen(),
      if (role == 'admin' || role == 'manager') const SalesScreen(),
    ];

    // final navItems = <BottomNavigationBarItem>[
    //   const BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
    //   if (role == 'admin' || role == 'manager' || role == 'employee')
    //     const BottomNavigationBarItem(
    //       icon: Icon(Icons.receipt),
    //       label: 'Orders',
    //     ),
    //   if (role == 'admin' || role == 'manager')
    //     const BottomNavigationBarItem(
    //       icon: Icon(Icons.attach_money),
    //       label: 'Sales',
    //     ),
    //   const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
    // ];

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
                  '$name (${role[0].toUpperCase()}${role.substring(1)})',
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
    final isEmployee = role == 'employee'; // ✅ ADD THIS
    final employeeName = user['name'] ?? '';
    final employeeOrders = appData.orders
        .where((order) => order['employee'] == employeeName)
        .toList(); // ✅ ADD THIS
    final employeeSales = appData.sales
        .where((sale) => sale['employee'] == employeeName)
        .toList(); // ✅ ADD TH

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('shops').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final shops = snapshot.data?.docs ?? [];
        // final activeShops = shops
        //     .where((shop) => shop['isDeleted'] != true)
        //     .toList();

        final assignedShops = (user['assignedShops'] ?? [])
            .map<String>((s) => s.toString())
            .toList();

        ('ROLE: $role');
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
                      value: isEmployee
                          ? employeeOrders.length.toString()
                          : appData.orders.length.toString(),
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
                      value: isEmployee
                          ? employeeSales.length.toString()
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
                              builder: (_) => const EmployeesOverviewScreen(),
                            ),
                          );
                        },
                      ),
                  ],
                ),

                // const SizedBox(height: 24),
                // const Text(
                //   "Quick Actions",
                //   style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                // ),
                // const SizedBox(height: 12),
                // Wrap(
                //   spacing: 20,
                //   runSpacing: 20,
                //   children: [
                //     if (role == 'admin' ||
                //         role == 'manager' ||
                //         role == 'employee')
                //       QuickActionButton(
                //         icon: Icons.add_shopping_cart,
                //         label: "Add Order",
                //         onTap: () {
                //           Navigator.push(
                //             context,
                //             MaterialPageRoute(
                //               builder: (_) => const AddOrderScreen(),
                //             ),
                //           );
                //         },
                //       ),
                //     if (role == 'admin' ||
                //         role == 'manager' ||
                //         role == 'employee')
                //       QuickActionButton(
                //         icon: Icons.attach_money,
                //         label: "Add Sale",
                //         onTap: () {
                //           Navigator.push(
                //             context,
                //             MaterialPageRoute(
                //               builder: (_) => const AddSaleScreen(),
                //             ),
                //           );
                //         },
                //       ),
                //     if (role == 'admin' || role == 'manager')
                //       QuickActionButton(
                //         icon: Icons.bar_chart,
                //         label: "Reports",
                //         onTap: () {
                //           Navigator.push(
                //             context,
                //             MaterialPageRoute(
                //               builder: (_) => const ReportsScreen(),
                //             ),
                //           );
                //         },
                //       ),
                //     if (role == 'admin' || role == 'manager')
                //       QuickActionButton(
                //         icon: Icons.add_business,
                //         label: "Add Shop",
                //         onTap: () {
                //           Navigator.push(
                //             context,
                //             MaterialPageRoute(
                //               builder: (_) => const AddShopScreen(),
                //             ),
                //           );
                //         },
                //       ),
                //     if (role == 'admin' || role == 'manager')
                //       QuickActionButton(
                //         icon: Icons.person_add_alt_1,
                //         label: "Add Employee + Access",
                //         onTap: () {
                //           Navigator.push(
                //             context,
                //             MaterialPageRoute(
                //               builder: (_) =>
                //                   const AddEmployeeAndAccessScreen(),
                //             ),
                //           );
                //         },
                //       ),
                //     QuickActionButton(
                //       icon: Icons.receipt_long,
                //       label: role == 'employee' ? "My Orders" : "Manage Orders",
                //       onTap: () {
                //         Navigator.push(
                //           context,
                //           MaterialPageRoute(
                //             builder: (_) => const OrdersScreen(),
                //           ),
                //         );
                //       },
                //     ),
                //   ],
                // ),
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
                              final shopName = shop['name'] ?? 'Unnamed';
                              final employees = shop['employees'] ?? [];
                              return ShopCard(
                                shopName: shopName,
                                employeeCount: employees.length,
                                isOpen: shop['isOpen'] ?? false,
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
