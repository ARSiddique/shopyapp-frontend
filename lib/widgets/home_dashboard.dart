import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';
import '../screens/shop_detail_screen.dart';
import '../widgets/summary_card.dart';
import '../widgets/quick_action_button.dart';
import '../widgets/shop_card.dart';
import '../screens/add_order_screen.dart';
import '../screens/add_sale_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/add_shop_screen.dart';
import '../screens/add_employee_and_access_screen.dart';
import '../screens/admin_orders_screen.dart';
import '../screens/all_shops_screen.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final user = appData.loggedInUser;
    final role = user?['role'] ?? '';

    if (role.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final String displayName = user?['name'] ?? 'User';
    final String displayRole = role[0].toUpperCase() + role.substring(1);

    List<Map<String, dynamic>> shops = [];
    if (role == 'admin' || role == 'manager') {
      shops = appData.shops;
    } else {
      final assigned = user?['assignedShops'] as List<String>? ?? [];
      shops = appData.shops
          .where((shop) => assigned.contains(shop['name']))
          .toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("$displayName ($displayRole)"),
        backgroundColor: Colors.deepPurple,
      ),
      body: SafeArea(
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
                    value: shops.length.toString(),
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
                alignment: WrapAlignment.spaceAround,
                children: [
                  QuickActionButton(
                    icon: Icons.add_shopping_cart,
                    label: "Add Order",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddOrderScreen(),
                        ),
                      );
                    },
                  ),
                  if (role != 'employee')
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
                  if (role == 'admin') ...[
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
                  ],
                  QuickActionButton(
                    icon: Icons.receipt,
                    label: role == 'admin' ? "Manage Orders" : "My Orders",
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
                        const Icon(Icons.store, size: 64, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text(
                          "No shops added yet.",
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 10),
                        if (role == 'admin')
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
                            final employeeCount =
                                shop['employees']?.length ?? 0;

                            return ShopCard(
                              shopName: shop['name'],
                              employeeCount: employeeCount,
                              isOpen: shop['isOpen'],
                              orderCount: orderCount,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ShopDetailScreen(
                                      shopName: shop['name'],
                                    ),
                                  ),
                                );
                              },
                              showDelete: role == 'admin',
                              onDelete: () {
                                appData.deleteShopByName(shop['name']);
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
      ),
    );
  }
}
