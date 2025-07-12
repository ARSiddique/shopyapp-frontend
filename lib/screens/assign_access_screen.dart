import 'package:flutter/material.dart';

class AssignAccessScreen extends StatefulWidget {
  const AssignAccessScreen({super.key});

  @override
  State<AssignAccessScreen> createState() => _AssignAccessScreenState();
}

class _AssignAccessScreenState extends State<AssignAccessScreen> {
  String? selectedEmployee;
  String role = 'Employee';

  List<String> employees = ['Ali Raza', 'Hassan', 'Ayesha'];
  List<String> shops = ['New York', 'Texas', 'Chicago'];
  Map<String, bool> shopAccess = {};

  @override
  void initState() {
    super.initState();
    // By default, no access is given
    for (var shop in shops) {
      shopAccess[shop] = false;
    }
  }

  void _saveAccess() {
    if (selectedEmployee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an employee")),
      );
      return;
    }

    // In real app, you'd store these values in backend
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Access updated successfully")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Assign Access"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            DropdownButtonFormField<String>(
              value: selectedEmployee,
              hint: const Text("Select Employee"),
              items: employees.map((e) {
                return DropdownMenuItem(value: e, child: Text(e));
              }).toList(),
              onChanged: (value) {
                setState(() => selectedEmployee = value);
              },
            ),
            const SizedBox(height: 20),

            const Text("Assign Role:", style: TextStyle(fontSize: 16)),
            Row(
              children: [
                Radio<String>(
                  value: 'Employee',
                  groupValue: role,
                  onChanged: (value) => setState(() => role = value!),
                ),
                const Text("Employee"),
                const SizedBox(width: 20),
                Radio<String>(
                  value: 'Manager',
                  groupValue: role,
                  onChanged: (value) => setState(() => role = value!),
                ),
                const Text("Manager"),
              ],
            ),

            const SizedBox(height: 20),
            const Text("Shop Access", style: TextStyle(fontSize: 16)),

            ...shops.map((shop) {
              return SwitchListTile(
                title: Text(shop),
                value: shopAccess[shop] ?? false,
                onChanged: (value) {
                  setState(() => shopAccess[shop] = value);
                },
              );
            }).toList(),

            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _saveAccess,
              icon: const Icon(Icons.check),
              label: const Text("Save Access"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
