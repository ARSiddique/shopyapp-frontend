import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

class SalesEditRequestsScreen extends StatelessWidget {
  const SalesEditRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);

    // 🔶 Simulated edit requests (You’ll later implement real ones via provider)
    final List<Map<String, dynamic>> editRequests = [
      {
        'id': 1,
        'employee': 'Ali Raza',
        'oldAmount': 1500,
        'newAmount': 1200,
        'reason': 'Mistaken input',
        'status': 'Pending',
      },
      {
        'id': 2,
        'employee': 'Hassan',
        'oldAmount': 3000,
        'newAmount': 2800,
        'reason': 'Customer returned one item',
        'status': 'Pending',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Sales Edit Requests"),
        backgroundColor: Colors.deepPurple,
      ),
      body: editRequests.isEmpty
          ? const Center(child: Text("No edit requests yet."))
          : ListView.builder(
              itemCount: editRequests.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (_, index) {
                final req = editRequests[index];
                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Employee: ${req['employee']}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text("Old Amount: Rs. ${req['oldAmount']}"),
                        Text("New Amount: Rs. ${req['newAmount']}"),
                        Text("Reason: ${req['reason']}"),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              icon: const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                              label: const Text(
                                "Approve",
                                style: TextStyle(color: Colors.green),
                              ),
                              onPressed: () {
                                // 🔧 Later: Update Provider sales
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Request Approved"),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 10),
                            TextButton.icon(
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              label: const Text(
                                "Reject",
                                style: TextStyle(color: Colors.red),
                              ),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Request Rejected"),
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
