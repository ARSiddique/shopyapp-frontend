import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_data_provider.dart';
import '../widgets/summary_card.dart';
import '../widgets/quick_action_button.dart';
import '../widgets/shop_card.dart';
import '../utils/logger.dart';

import '../screens/add_sale_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/add_employee_screen.dart';
import '../screens/add_shop_screen.dart';
import '../screens/assign_access_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/orders_screen.dart';
import '../screens/add_order_screen.dart';
import '../screens/sales_screen.dart';
import '../screens/admin_orders_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final user = appData.loggedInUser;
    final role = user?['role'] ?? 'admin';

    // Create tab list based on role
    final List<Widget> pages = [
      const HomeDashboard(),
      if (role == 'admin' || role == 'manager' || role == 'employee')
        const OrdersScreen(),
      if (role == 'admin' || role == 'manager') const SalesScreen(),
      if (role == 'admin') const ProfileScreen(),
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
      if (role == 'admin')
        const BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: "Profile",
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Shopy App"),
        backgroundColor: Colors.deepPurple,
        elevation: 4,
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
    final user = appData.loggedInUser;
    final role = user?['role'] ?? 'admin';

    List<Map<String, dynamic>> shops = [];

    if (role == 'admin') {
      shops = appData.shops;
    } else {
      final assigned = user?['assignedShops'] as List<String>? ?? [];
      shops = appData.shops
          .where((shop) => assigned.contains(shop['name']))
          .toList();
    }

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

            // 📊 Summary Cards
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
                SummaryCard(
                  icon: Icons.trending_up,
                  title: 'Total Sales',
                  value: 'Rs. ${appData.totalSales.toStringAsFixed(0)}',
                  color: Colors.teal,
                ),
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
                SummaryCard(
                  icon: Icons.people,
                  title: 'Employees',
                  value: appData.totalEmployees.toString(),
                  color: Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ⚡ Quick Actions
            const Text(
              "Quick Actions",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
           Wrap(
              spacing: 20,
              runSpacing: 20,
              alignment: WrapAlignment.spaceAround,
              children: [
                // Common to All Roles
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

                // Manager + Admin
                if (role == 'admin' || role == 'manager')
                  QuickActionButton(
                    icon: Icons.attach_money,
                    label: "Add Sale",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddSaleScreen(),
                        ),
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

                // Admin Only
                if (role == 'admin') ...[
                  QuickActionButton(
                    icon: Icons.settings,
                    label: "Settings",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      );
                    },
                  ),
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
                  QuickActionButton(
                    icon: Icons.person_add,
                    label: "Add Employee",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddEmployeeScreen(),
                        ),
                      );
                    },
                  ),
                  QuickActionButton(
                    icon: Icons.vpn_key,
                    label: "Assign Access",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AssignAccessScreen(),
                        ),
                      );
                    },
                  ),
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
                  ),
                ],

                // Employee (or All)
                if (role == 'admin' || role == 'employee')
                  QuickActionButton(
                    icon: Icons.receipt,
                    label: "View Orders",
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
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text("Add Your First Shop"),
                        onPressed: () {
                          Navigator.pushNamed(context, '/add-shop');
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
                            employees: shop['employees'],
                            isOpen: shop['isOpen'],
                            orderCount: orderCount, // ✅ This is good!
                            onCheckIn: () =>
                                log.info("Checked into ${shop['name']}"),
                          );
                        },
                      ),
                      if (shops.length > 3)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/all-shops');
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
