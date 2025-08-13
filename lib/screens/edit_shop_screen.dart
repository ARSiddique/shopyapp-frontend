import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

class EditShopScreen extends StatefulWidget {
  final Map<String, dynamic> shopData;

  const EditShopScreen({super.key, required this.shopData});

  @override
  State<EditShopScreen> createState() => _EditShopScreenState();
}

class _EditShopScreenState extends State<EditShopScreen> {
  late TextEditingController _nameController;
  late bool _isOpen;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.shopData['name']);
    _isOpen = widget.shopData['isOpen'] ?? true;
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context, listen: false);
    final originalName = widget.shopData['name'];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Shop"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Shop Name",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text("Shop Status: "),
                const SizedBox(width: 10),
                Switch(
                  value: _isOpen,
                  onChanged: (val) => setState(() => _isOpen = val),
                  activeColor: Colors.green,
                ),
                Text(_isOpen ? "Open" : "Closed"),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text("Save Changes"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  appData.updateShop(originalName, {
                    'name': _nameController.text.trim(),
                    'isOpen': _isOpen,
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Shop updated successfully.")),
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
