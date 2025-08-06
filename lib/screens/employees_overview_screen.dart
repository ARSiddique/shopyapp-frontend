import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';
import 'add_employee_and_access_screen.dart';

class EmployeesOverviewScreen extends StatefulWidget {
  const EmployeesOverviewScreen({super.key});

  @override
  State<EmployeesOverviewScreen> createState() =>
      _EmployeesOverviewScreenState();
}

class _EmployeesOverviewScreenState extends State<EmployeesOverviewScreen> {
  Future<void> _confirmDeleteEmployee(Map<String, dynamic> employee) async {
    if ((employee['role'] ?? '') == 'admin') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You cannot delete an Admin"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: Text("Are you sure you want to delete ${employee['name']}?"),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          TextButton(
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final uid = employee['uid'];
      await FirebaseFirestore.instance
          .collection('employees')
          .doc(uid)
          .delete();
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${employee['name']} deleted successfully')),
      );

      await Provider.of<AppDataProvider>(
        context,
        listen: false,
      ).fetchEmployees();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting employee: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employees'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddEmployeeAndAccessScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('employees').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text('No employees found.'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final raw = docs[index].data();
              if (raw is! Map<String, dynamic>) return const SizedBox();
              final data = raw;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(data['name'] ?? 'No Name'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Role: ${data['role'] ?? 'N/A'}'),
                      Text('Email: ${data['email'] ?? 'N/A'}'),
                      Text(
                        'Assigned Shops: ${((data['assignedShops'] ?? []) as List).join(', ')}',
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () async {
                          // ✅ Move Provider call BEFORE await
                          final appData = Provider.of<AppDataProvider>(
                            context,
                            listen: false,
                          );

                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddEmployeeAndAccessScreen(
                                existingEmployee: data,
                              ),
                            ),
                          );

                          if (!mounted) return;

                          if (result != null &&
                              result is Map<String, dynamic> &&
                              result.containsKey('assignedShops')) {
                            await appData.updateShopAssignments(
                              userId: data['uid'],
                              userName: data['name'],
                              newAssignedShops: List<String>.from(
                                result['assignedShops'],
                              ),
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDeleteEmployee(data),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
