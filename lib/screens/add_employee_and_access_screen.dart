import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

class AddEmployeeAndAccessScreen extends StatefulWidget {
  const AddEmployeeAndAccessScreen({super.key});

  @override
  State<AddEmployeeAndAccessScreen> createState() =>
      _AddEmployeeAndAccessScreenState();
}

class _AddEmployeeAndAccessScreenState
    extends State<AddEmployeeAndAccessScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final loginCodeController = TextEditingController();

  String selectedRole = 'employee';
  List<String> selectedShops = [];

  void _toggleShop(String shopName) {
    setState(() {
      if (selectedShops.contains(shopName)) {
        selectedShops.remove(shopName);
      } else {
        selectedShops.add(shopName);
      }
    });
  }

  bool _isFormValid() {
    return nameController.text.trim().isNotEmpty &&
        phoneController.text.trim().isNotEmpty &&
        loginCodeController.text.trim().isNotEmpty &&
        selectedShops.isNotEmpty &&
        loginCodeController.text.trim().length >= 4;
  }

  void _saveData() {
    final appData = Provider.of<AppDataProvider>(context, listen: false);
    final loginCode = loginCodeController.text.trim();

    // Prevent duplicate loginCode
    if (appData.employees.any((e) => e['loginCode'] == loginCode)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Login code already exists!')),
      );
      return;
    }

    final employee = {
      'name': nameController.text.trim(),
      'phone': phoneController.text.trim(),
      'loginCode': loginCode,
      'role': selectedRole,
      'assignedShops': selectedShops,
    };

    appData.addEmployee(employee);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('✅ Employee & Access Saved')));

    // Reset form
    nameController.clear();
    phoneController.clear();
    loginCodeController.clear();
    setState(() {
      selectedShops.clear();
      selectedRole = 'employee';
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final shops = Provider.of<AppDataProvider>(context).shops;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Employee + Access"),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          onChanged: () => setState(() {}),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 👤 Employee Name
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Employee Name",
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val!.isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 12),

              // 📞 Phone Number
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "Phone Number",
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val!.isEmpty ? 'Enter phone number' : null,
              ),
              const SizedBox(height: 12),

              // 🔐 Login Code
              TextFormField(
                controller: loginCodeController,
                decoration: const InputDecoration(
                  labelText: "Login Code (min 4 chars)",
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val!.length < 4 ? 'Login code too short' : null,
              ),
              const SizedBox(height: 20),

              // 👔 Assign Role
              const Text(
                "Assign Role",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  Radio(
                    value: 'employee',
                    groupValue: selectedRole,
                    onChanged: (value) => setState(() => selectedRole = value!),
                  ),
                  const Text("Employee"),
                  Radio(
                    value: 'manager',
                    groupValue: selectedRole,
                    onChanged: (value) => setState(() => selectedRole = value!),
                  ),
                  const Text("Manager"),
                ],
              ),
              const SizedBox(height: 20),

              // 🏬 Assign Shops
              const Text(
                "Assign Shops",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (shops.isEmpty)
                const Text("No shops found. Please add shops first."),
              if (shops.isNotEmpty)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: shops.map((shop) {
                    final shopName = shop['name'] ?? 'Unnamed';
                    return FilterChip(
                      label: Text(shopName),
                      selected: selectedShops.contains(shopName),
                      onSelected: (_) => _toggleShop(shopName),
                      selectedColor: Colors.deepPurple,
                      checkmarkColor: Colors.white,
                    );
                  }).toList(),
                ),

              const SizedBox(height: 30),

              // 💾 Save Button
              ElevatedButton.icon(
                onPressed: _isFormValid() ? _saveData : null,
                icon: const Icon(Icons.save),
                label: const Text("Save Employee & Access"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  disabledBackgroundColor: Colors.deepPurple.shade200,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
