import 'package:flutter/material.dart';

class AddShopScreen extends StatefulWidget {
  const AddShopScreen({super.key});

  @override
  State<AddShopScreen> createState() => _AddShopScreenState();
}

class _AddShopScreenState extends State<AddShopScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _shopNameController = TextEditingController();

  bool isOpen = true;

  void _submit() {
    if (_formKey.currentState!.validate()) {
      // In real app: Save to database
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Shop added successfully!")));

      _shopNameController.clear();
      setState(() {
        isOpen = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Shop"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _shopNameController,
                decoration: const InputDecoration(labelText: "Shop Name"),
                validator: (value) =>
                    value == null || value.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Shop Status", style: TextStyle(fontSize: 16)),
                  Switch(
                    value: isOpen,
                    activeColor: Colors.green,
                    onChanged: (value) {
                      setState(() => isOpen = value);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.store),
                label: const Text("Add Shop"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
