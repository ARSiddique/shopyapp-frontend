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

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController loginCodeController = TextEditingController();

  String selectedRole = 'employee';
  String? selectedShop;

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final shops = appData.shops;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Employee & Access"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Employee Details",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Name
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 16),

                // Email (must end with @gmail.com)
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email (@gmail.com only)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email is required';
                    } else if (!value.endsWith('@gmail.com')) {
                      return 'Only @gmail.com allowed';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Phone number (numeric keypad)
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Phone number is required'
                      : null,
                ),
                const SizedBox(height: 16),

                // Login Code
                TextFormField(
                  controller: loginCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Login Code',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.key),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Login code is required'
                      : null,
                ),
                const SizedBox(height: 16),

                // Role Selection
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  items: const [
                    DropdownMenuItem(
                      value: 'employee',
                      child: Text("Employee"),
                    ),
                    DropdownMenuItem(value: 'manager', child: Text("Manager")),
                  ],
                  onChanged: (value) =>
                      setState(() => selectedRole = value ?? 'employee'),
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.group),
                  ),
                ),
                const SizedBox(height: 16),

                // Single Shop Assignment
                DropdownButtonFormField<String>(
                  value: selectedShop,
                  items: shops.map<DropdownMenuItem<String>>((shop) {
                    return DropdownMenuItem(
                      value: shop['name'],
                      child: Text(shop['name']),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => selectedShop = value),
                  decoration: const InputDecoration(
                    labelText: 'Assign Shop',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.store),
                  ),
                  validator: (value) {
                    if (selectedRole == 'employee' &&
                        (value == null || value.isEmpty)) {
                      return 'Employees must be assigned to one shop';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text("Add Employee"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        final employeeData = {
                          'name': nameController.text.trim(),
                          'email': emailController.text.trim(),
                          'phone': phoneController.text.trim(),
                          'loginCode': loginCodeController.text.trim(),
                          'role': selectedRole,
                          'assignedShops': selectedShop != null
                              ? [selectedShop!]
                              : [],
                        };

                        appData.addEmployee(employeeData);

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Employee added successfully"),
                          ),
                        );

                        Navigator.pop(context);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
