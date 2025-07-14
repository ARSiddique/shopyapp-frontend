import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_data_provider.dart';
import '../widgets/summary_card.dart';
import '../widgets/quick_action_button.dart';
import '../widgets/shop_card.dart';
import '../utils/logger.dart';

import '../screens/add_order_screen.dart';
import '../screens/add_sale_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/add_employee_and_access_screen.dart';
import '../screens/add_shop_screen.dart';
import '../screens/add_employee_and_access_screen.dart';
import '../screens/admin_orders_screen.dart';
import '../screens/reports_screen.dart';

class HomeDashboard extends StatelessWidget {
  const HomeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final user = appData.loggedInUser;
    final role = user?['role'] ?? 'admin';

    // Filter shops based on assigned shops if not admin
    List<Map<String, dynamic>> shops = role == 'admin'
        ? appData.shops
        : appData.shops
              .where(
                (shop) => (user?['assignedShops'] ?? []).contains(shop['name']),
              )
              .toList();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Dashboard Summary",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

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
                // Common
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
                if (role == 'admin' || role == 'manager') ...[
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
                ],

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
                          builder: (_) => const AddEmployeeAndAccessScreen(),
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
                          builder: (_) => const AddEmployeeAndAccessScreen(),
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
              ],
            ),

            const SizedBox(height: 32),
            const Text(
              "Shops Overview",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

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
                      if (role == 'admin')
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text("Add Shop"),
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
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: shops.length >= 3 ? 3 : shops.length,
                    itemBuilder: (_, index) {
                      final shop = shops[index];

                      final employeeList = (shop['employees'] ?? []) as List;
                      final employeeCount = employeeList.length;

                      final orderCount = appData.orders
                          .where((order) => order['shop'] == shop['name'])
                          .length;

                      return ShopCard(
                        shopName: shop['name'],
                        employees: employeeCount, // ✅ CORRECT
                        isOpen: shop['isOpen'],
                        orderCount: orderCount,
                        onCheckIn: () =>
                            log.info("Checked into ${shop['name']}"),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
