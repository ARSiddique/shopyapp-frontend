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
    final shops = appData.shops.where((shop) {
      return shop['name'].toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

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
              child: shops.isEmpty
                  ? const Center(child: Text("No shops found."))
                  : ListView.builder(
                      itemCount: shops.length,
                      itemBuilder: (_, index) {
                        final shop = shops[index];
                        final employeeList = shop['employees'] ?? [];
                        final orderCount = appData.orders
                            .where((o) => o['shop'] == shop['name'])
                            .length;

                        return Card(
                          elevation: 3,
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ExpansionTile(
                            leading: const Icon(Icons.store),
                            title: Text(shop['name']),
                            subtitle: Text("Orders: $orderCount"),
                            children: [
                              ListTile(
                                title: Text(
                                  "Status: ${shop['isOpen'] ? 'Open' : 'Closed'}",
                                ),
                                trailing: ElevatedButton.icon(
                                  icon: const Icon(Icons.edit),
                                  label: const Text("Edit Shop"),
                                  onPressed: () {
                                    // TODO: Implement Edit Shop logic
                                  },
                                ),
                              ),

                              // 👥 Employees List
                              if (employeeList.isEmpty)
                                const ListTile(
                                  title: Text("No employees assigned"),
                                )
                              else
                                ...employeeList.map<Widget>((empName) {
                                  final employee = appData.getEmployeeByName(
                                    empName,
                                  );
                                  return ExpansionTile(
                                    title: Text(empName),
                                    children: [
                                      ListTile(
                                        title: Text(
                                          "Email: ${employee['email'] ?? '-'}",
                                        ),
                                        subtitle: Text(
                                          "Phone: ${employee['phone'] ?? '-'}",
                                        ),
                                      ),
                                    ],
                                  );
                                }),

                              // 🗑 Delete Button
                              ListTile(
                                leading: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                title: const Text("Delete Shop"),
                                onTap: () {
                                  showDeleteShopDialog(
                                    context: context,
                                    shopName: shop['name'],
                                    onConfirmed: () {
                                      appData.deleteShop(index);
                                    },
                                  );
                                },
                              ),

                              // ℹ️ View Details Button
                              ListTile(
                                leading: const Icon(Icons.info_outline),
                                title: const Text("View Full Details"),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ShopDetailScreen(
                                        shopName: shop['name'],
                                        isOpen: shop['isOpen'],
                                      ),
                                    ),
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
