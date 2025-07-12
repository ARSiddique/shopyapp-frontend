import 'package:flutter/material.dart';

class AddEmployeeScreen extends StatefulWidget {
  const AddEmployeeScreen({super.key});

  @override
  State<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  String? selectedShop;
  List<String> shops = ["New York", "Texas", "Chicago"];

  void _submitForm() {
    if (_formKey.currentState!.validate() && selectedShop != null) {
      // Here, you will save to backend later
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Employee added successfully.")),
      );
      _nameController.clear();
      _phoneController.clear();
      _codeController.clear();
      setState(() => selectedShop = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Employee"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Employee Name"),
                validator: (value) =>
                    value == null || value.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: "Phone Number"),
                keyboardType: TextInputType.phone,
                validator: (value) =>
                    value == null || value.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: "Login Code"),
                obscureText: true,
                validator: (value) =>
                    value == null || value.length < 4 ? "Min 4 chars" : null,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: selectedShop,
                items: shops.map((shop) {
                  return DropdownMenuItem(value: shop, child: Text(shop));
                }).toList(),
                hint: const Text("Assign to Shop"),
                onChanged: (value) {
                  setState(() {
                    selectedShop = value;
                  });
                },
                validator: (value) => value == null ? "Select a shop" : null,
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _submitForm,
                icon: const Icon(Icons.person_add),
                label: const Text("Add Employee"),
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
