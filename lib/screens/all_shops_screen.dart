import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_data_provider.dart';
import '../utils/delete_shop_dialog.dart';
import 'shop_detail_screen.dart';

class AllShopsScreen extends StatefulWidget {
  const AllShopsScreen({super.key});

  @override
  State<AllShopsScreen> createState() => _AllShopsScreenState();
}

class _AllShopsScreenState extends State<AllShopsScreen> {
  String searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final user = appData.loggedInUser;
    final role = user?['role'] ?? 'employee';
    final isAdmin = role == 'admin' || role == 'owner';

    final visibleShops = appData.shops
        .where(
          (shop) =>
              shop['isDeleted'] != true &&
              shop['name'].toLowerCase().contains(searchQuery.toLowerCase()),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("All Shops"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: "Search by shop name",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => searchQuery = val),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: visibleShops.isEmpty
                  ? const Center(child: Text("No shops found."))
                  : ListView.builder(
                      itemCount: visibleShops.length,
                      itemBuilder: (_, index) {
                        final shop = visibleShops[index];
                        final shopName = shop['name'];
                        final employeeNames = shop['employees'] ?? [];
                        final orderCount = appData.orders
                            .where((o) => o['shop'] == shopName)
                            .length;

                        return Card(
                          elevation: 3,
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ExpansionTile(
                            leading: const Icon(Icons.store),
                            title: Text(shopName),
                            subtitle: Text("Orders: $orderCount"),
                            children: [
                              ListTile(
                                title: Text(
                                  "Status: ${shop['isOpen'] == true ? 'Open' : 'Closed'}",
                                ),
                              ),
                              if (employeeNames.isEmpty)
                                const ListTile(
                                  title: Text("No employees assigned"),
                                )
                              else
                                ...employeeNames.map<Widget>((empName) {
                                  final emp = appData.getEmployeeByName(
                                    empName,
                                  );
                                  if (emp.isEmpty) return const SizedBox();

                                  final shops = emp['assignedShops'] ?? [];

                                  return ListTile(
                                    title: Text(emp['name'] ?? '-'),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text("Email: ${emp['email'] ?? '-'}"),
                                        Text("Phone: ${emp['phone'] ?? '-'}"),
                                        Text("Role: ${emp['role'] ?? '-'}"),
                                        Text(
                                          "Login Code: ${emp['loginCode'] ?? '-'}",
                                        ),
                                        Text(
                                          "Assigned Shops: ${shops.isEmpty ? '-' : shops.join(', ')}",
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),

                              const Divider(),

                              // View Details Button
                              ListTile(
                                leading: const Icon(Icons.info_outline),
                                title: const Text("View Full Details"),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ShopDetailScreen(shopName: shopName),
                                    ),
                                  );
                                },
                              ),

                              // Delete Shop Button
                              if (isAdmin)
                                ListTile(
                                  leading: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  title: const Text("Delete Shop"),
                                  onTap: () {
                                    showDeleteShopDialog(
                                      context: context,
                                      shopName: shopName,
                                      onConfirmed: () {
                                        appData.deleteShopByName(shopName);
                                      },
                                    );
                                  },
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
