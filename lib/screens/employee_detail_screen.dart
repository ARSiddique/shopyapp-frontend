import 'package:flutter/material.dart';
import 'assignment_history_screen.dart'; // Make sure this import is correct

class EmployeeDetailScreen extends StatelessWidget {
  final Map<String, dynamic> employee;
  const EmployeeDetailScreen({super.key, required this.employee});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Details'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              employee['name'] ?? 'Unknown',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            Text('Role: ${employee['role'] ?? ''}'),
            Text('Code: ${employee['code'] ?? ''}'),
            Text('Assigned Shop: ${employee['assignedShop'] ?? 'None'}'),
            const SizedBox(height: 30),

            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to edit screen
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text("Edit"),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    // Add delete confirmation
                  },
                  icon: const Icon(Icons.delete),
                  label: const Text("Delete"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            ),

            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AssignmentHistoryScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.history),
              label: const Text("View Assignment History"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
