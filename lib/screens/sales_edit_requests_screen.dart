import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

class SalesEditRequestsScreen extends StatefulWidget {
  const SalesEditRequestsScreen({super.key});

  @override
  State<SalesEditRequestsScreen> createState() =>
      _SalesEditRequestsScreenState();
}

class _SalesEditRequestsScreenState extends State<SalesEditRequestsScreen> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final requests = appData.editRequests
        .where((r) => r['type'] == 'sale' && r['status'] == 'pending')
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Edit Requests'),
        backgroundColor: Colors.deepPurple,
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : requests.isEmpty
          ? const Center(child: Text('No edit requests for sales'))
          : ListView.separated(
              itemCount: requests.length,
              padding: const EdgeInsets.all(16),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, index) {
                final request = requests[index];
                final requestId = request['firebaseId'];
                final saleId = request['itemId'].toString();
                final newAmount = request['newAmount'] ?? 0.0;

                return Card(
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('🔧 Request ID: $requestId'),
                        Text('👤 Requested By: ${request['requestedBy']}'),
                        Text('🧾 Sale ID: $saleId'),
                        Text('💲 New Amount: $newAmount'),
                        Text('📄 Reason: ${request['reason']}'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.check),
                              label: const Text('Approve'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                              onPressed: () async {
                                setState(() => _isProcessing = true);
                                await appData.approveSaleEdit(requestId);
                                setState(() => _isProcessing = false);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Request approved'),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.close),
                              label: const Text('Reject'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: () async {
                                setState(() => _isProcessing = true);
                                await appData.rejectSaleEdit(requestId);
                                setState(() => _isProcessing = false);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Request rejected'),
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
