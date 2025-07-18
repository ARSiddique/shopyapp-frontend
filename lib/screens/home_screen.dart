import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';
import '../widgets/summary_card.dart';
import '../widgets/quick_action_button.dart';
import '../widgets/shop_card.dart';
import '../screens/add_sale_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/add_employee_and_access_screen.dart';
import '../screens/add_shop_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/orders_screen.dart';
import '../screens/add_order_screen.dart';
import '../screens/sales_screen.dart';
import '../screens/admin_orders_screen.dart';
import '../screens/login_screen.dart';
import '../screens/all_shops_screen.dart';
import '../screens/shop_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

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

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final user = appData.loggedInUser ?? {};
    final name = user['name'] ?? 'User';
    final role = (user['role'] ?? 'employee').toString().toLowerCase();

    final List<Widget> pages = [
      const HomeDashboard(),
      if (role == 'admin' || role == 'manager' || role == 'employee')
        const OrdersScreen(),
      if (role == 'admin' || role == 'manager') const SalesScreen(),
      const ProfileScreen(), // ✅ Now available to all roles
    ];

    final List<BottomNavigationBarItem> navItems = [
      const BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Home"),
      if (role == 'admin' || role == 'manager' || role == 'employee')
        const BottomNavigationBarItem(
          icon: Icon(Icons.receipt),
          label: "Orders",
        ),
      if (role == 'admin' || role == 'manager')
        const BottomNavigationBarItem(
          icon: Icon(Icons.attach_money),
          label: "Sales",
        ),
      const BottomNavigationBarItem(
        // ✅ Shown to all roles
        icon: Icon(Icons.person),
        label: "Profile",
      ),
    ];

    if (navItems.length < 2) {
      return const Scaffold(
        body: Center(child: Text("Invalid role or insufficient menu items.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: Text(
          "$name (${role[0].toUpperCase()}${role.substring(1)})",
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: "Logout",
            onPressed: () => showPlatformLogoutDialog(context),
          ),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        items: navItems,
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
    debugPrint("👤 Logged in user: $user");

    // 👤 Get employee assigned shops
    final rawAssigned = user['assignedShops'] ?? <dynamic>[];
    final assignedShops = List<String>.from(rawAssigned);

    final List<Map<String, dynamic>> shops =
        (role == 'admin' || role == 'manager')
        ? appData.shops
        : appData.shops
              .where((shop) => assignedShops.contains(shop['name']))
              .toList();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Dashboard Overview",
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
                  value: appData.totalOrders.toString(),
                  color: Colors.deepPurple,
                ),
                if (role != 'employee')
                  SummaryCard(
                    icon: Icons.trending_up,
                    title: 'Total Sales',
                    value: 'Rs. ${appData.totalSales.toStringAsFixed(0)}',
                    color: Colors.teal,
                  ),
                if (role != 'employee')
                  SummaryCard(
                    icon: Icons.money,
                    title: 'Expenses',
                    value: 'Rs. 0',
                    color: Colors.green,
                  ),
                SummaryCard(
                  icon: Icons.store,
                  title: 'Shops',
                  value: appData.totalShops.toString(),
                  color: Colors.orange,
                ),
                if (role == 'admin' || role == 'manager')
                  SummaryCard(
                    icon: Icons.people,
                    title: 'Employees',
                    value: appData.totalEmployees.toString(),
                    color: Colors.blue,
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              "Quick Actions",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 20,
              runSpacing: 20,
              children: [
                QuickActionButton(
                  icon: Icons.add_shopping_cart,
                  label: "Add Order",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddOrderScreen()),
                    );
                  },
                ),
                QuickActionButton(
                  icon: Icons.attach_money,
                  label: "Add Sale",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddSaleScreen()),
                    );
                  },
                ),
                if (role == 'admin' || role == 'manager')
                  QuickActionButton(
                    icon: Icons.bar_chart,
                    label: "Reports",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ReportsScreen(),
                        ),
                      );
                    },
                  ),
                if (role == 'admin')
                  QuickActionButton(
                    icon: Icons.add_business,
                    label: "Add Shop",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddShopScreen(),
                        ),
                      );
                    },
                  ),
                if (role == 'admin')
                  QuickActionButton(
                    icon: Icons.person_add_alt_1,
                    label: "Add Employee + Access",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddEmployeeAndAccessScreen(),
                        ),
                      );
                    },
                  ),
                if (role == 'admin' || role == 'manager')
                  QuickActionButton(
                    icon: Icons.admin_panel_settings,
                    label: "Manage Orders",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminOrdersScreen(),
                        ),
                      );
                    },
                  )
                else
                  QuickActionButton(
                    icon: Icons.receipt_long,
                    label: "My Orders",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminOrdersScreen(),
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
            shops.isEmpty
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
                        itemCount: shops.length >= 3 ? 3 : shops.length,
                        itemBuilder: (_, index) {
                          final shop = shops[index];
                          final orderCount = appData.orders
                              .where((order) => order['shop'] == shop['name'])
                              .length;

                          return ShopCard(
                            shopName: shop['name'],
                            employeeCount: shop['employees']?.length ?? 0,
                            isOpen: shop['isOpen'],
                            orderCount: orderCount,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ShopDetailScreen(shopName: shop['name']),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      if (shops.length > 3)
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
  }
}
