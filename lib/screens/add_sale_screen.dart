import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

class AddSaleScreen extends StatefulWidget {
  const AddSaleScreen({super.key});

  @override
  State<AddSaleScreen> createState() => _AddSaleScreenState();
}

class _AddSaleScreenState extends State<AddSaleScreen> {
  double cash = 0;
  double card = 0;
  double venmo = 0;
  bool submitted = false;

  void _submitSale() {
    final appData = Provider.of<AppDataProvider>(context, listen: false);
    final user = appData.loggedInUser;

    final sale = {
      'amount': cash + card + venmo,
      'cash': cash,
      'card': card,
      'venmo': venmo,
      'submittedBy': user?['name'] ?? 'Unknown',
      'timestamp': DateTime.now().toString(),
    };

    appData.addSale(sale);

    setState(() {
      submitted = true;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Sale submitted.")));
  }

  Widget _saleInputTile(
    String label,
    double value,
    Function(double) onChanged,
  ) {
    return ListTile(
      title: Text(label),
      subtitle: Text("Rs. ${value.toStringAsFixed(0)}"),
      trailing: !submitted
          ? IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final result = await _showInputBottomSheet(label);
                if (result != null) onChanged(result);
              },
            )
          : const Icon(Icons.lock, color: Colors.grey),
    );
  }

  Future<double?> _showInputBottomSheet(String label) async {
    String input = '';
    return await showModalBottomSheet<double>(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Enter $label", style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 10),
                  Text(input, style: const TextStyle(fontSize: 32)),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children:
                        List.generate(10, (index) {
                          return ElevatedButton(
                            onPressed: () =>
                                setState(() => input += index.toString()),
                            child: Text('$index'),
                          );
                        }) +
                        [
                          ElevatedButton(
                            onPressed: () {
                              setState(
                                () => input = input.isNotEmpty
                                    ? input.substring(0, input.length - 1)
                                    : '',
                              );
                            },
                            child: const Icon(Icons.backspace),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(
                                context,
                                double.tryParse(input) ?? 0,
                              );
                            },
                            child: const Text("OK"),
                          ),
                        ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final userRole = appData.loggedInUser?['role'];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Sale"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _saleInputTile("Cash", cash, (val) => setState(() => cash = val)),
            _saleInputTile("Card", card, (val) => setState(() => card = val)),
            _saleInputTile(
              "Venmo",
              venmo,
              (val) => setState(() => venmo = val),
            ),
            const SizedBox(height: 20),
            if (!submitted)
              ElevatedButton.icon(
                onPressed: _submitSale,
                icon: const Icon(Icons.check),
                label: const Text("Submit Sale"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            if (submitted) const Text("Sale Submitted ✅"),

            const Divider(height: 40),

            // 🚫 Hide totals from employee
            if (userRole != 'employee') ...[
              Text(
                "Total: Rs. ${(cash + card + venmo).toStringAsFixed(0)}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
