import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';
import 'add_employee_and_access_screen.dart';
import 'assignment_history_screen.dart';

class EmployeesOverviewScreen extends StatelessWidget {
  const EmployeesOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final employees = appData.employees;
    final user = appData.loggedInUser ?? {};
    final isAdmin = user['role'] == 'admin';
    final isManager = user['role'] == 'manager';
    final userId = user['id'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Employees'),
        backgroundColor: Colors.deepPurple,
        actions: [
          if (isAdmin || isManager)
            IconButton(
              icon: const Icon(Icons.person_add),
              tooltip: 'Add Employee',
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
      body: employees.isEmpty
          ? const Center(child: Text('No employees found'))
          : ListView.builder(
              itemCount: employees.length,
              padding: const EdgeInsets.all(12),
              itemBuilder: (context, index) {
                final emp = employees[index];
                final assignedShops = emp['assignedShops'] ?? [];
                final isSelf = emp['id'] == userId;

                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          emp['name'] ?? 'N/A',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('Phone: ${emp['phone'] ?? 'N/A'}'),
                        Text('Email: ${emp['email'] ?? 'N/A'}'),
                        Text('Role: ${emp['role']}'),
                        if (assignedShops.isNotEmpty)
                          Text('Shops: ${assignedShops.join(', ')}'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.edit),
                              label: Text(isSelf ? 'Edit Self' : 'Edit'),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddEmployeeAndAccessScreen(
                                      existingEmployee: emp,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.history),
                              label: const Text('History'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AssignmentHistoryScreen(
                                      employeeId: emp['id'],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
