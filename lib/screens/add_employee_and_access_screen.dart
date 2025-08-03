import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddEmployeeAndAccessScreen extends StatefulWidget {
  final Map<String, dynamic>? existingEmployee;

  const AddEmployeeAndAccessScreen({super.key, this.existingEmployee});

  @override
  State<AddEmployeeAndAccessScreen> createState() =>
      _AddEmployeeAndAccessScreenState();
}

class _AddEmployeeAndAccessScreenState
    extends State<AddEmployeeAndAccessScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final List<String> _selectedShops = [];

  String _selectedRole = 'employee';
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();

    if (widget.existingEmployee != null) {
      _isEditMode = true;
      final emp = widget.existingEmployee!;
      _nameController.text = emp['name'] ?? '';
      _phoneController.text = emp['phone'] ?? '';
      _emailController.text = emp['email'] ?? '';
      _selectedRole = emp['role'] ?? 'employee';
      _selectedShops.addAll(
        (emp['assignedShops'] as List?)?.map((e) => e.toString()) ?? [],
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // Manager uniqueness check only when adding
      if (!_isEditMode && _selectedRole == 'manager') {
        final existingManager = await FirebaseFirestore.instance
            .collection('employees')
            .where('role', isEqualTo: 'manager')
            .get();
        if (existingManager.docs.isNotEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Only one manager is allowed.'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      if (_selectedRole == 'employee' && _selectedShops.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please assign at least one shop to this employee.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Assign shop updates
      if (_selectedRole == 'employee') {
        for (String shopName in _selectedShops) {
          final query = await FirebaseFirestore.instance
              .collection('shops')
              .where('name', isEqualTo: shopName)
              .limit(1)
              .get();
          if (query.docs.isNotEmpty) {
            final shopDoc = query.docs.first.reference;
            await shopDoc.update({
              'employees': FieldValue.arrayUnion([_nameController.text.trim()]),
            });
          }
        }
      }

      final employeeData = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'assignedShops': _selectedRole == 'manager'
            ? []
            : List.from(_selectedShops),
        'role': _selectedRole,
        'updatedAt': Timestamp.now(),
      };

      if (_isEditMode) {
        final id = widget.existingEmployee!['uid'];
        await FirebaseFirestore.instance
            .collection('employees')
            .doc(id)
            .update(employeeData);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(id)
            .update(employeeData);
      } else {
        final password = _passwordController.text.trim();
        final userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: password,
            );
        final uid = userCredential.user?.uid;
        if (uid == null) throw Exception('UID generation failed');

        employeeData.addAll({
          'uid': uid,
          'password': password,
          'loginCode': password,
          'createdAt': Timestamp.now(),
        });

        await FirebaseFirestore.instance
            .collection('employees')
            .doc(uid)
            .set(employeeData);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set(employeeData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditMode
                  ? 'Employee updated successfully'
                  : 'Employee added successfully',
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Edit Employee' : 'Add Employee & Assign Access',
        ),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                readOnly: _isEditMode,
                validator: (val) =>
                    val == null || val.isEmpty ? 'Enter name' : null,
              ),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Enter phone' : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                readOnly: _isEditMode,
                validator: (val) =>
                    val == null || val.isEmpty ? 'Enter email' : null,
              ),
              if (!_isEditMode)
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password / Login Code',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (val) => val == null || val.length < 4
                      ? 'Minimum 4 characters'
                      : null,
                ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'employee', child: Text('Employee')),
                  DropdownMenuItem(value: 'manager', child: Text('Manager')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedRole = val);
                  }
                },
              ),
              const SizedBox(height: 16),
              const Text('Assign Shops (Optional for Managers/Admin):'),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('shops')
                    .where('isDeleted', isEqualTo: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final shopDocs = snapshot.data!.docs;
                  if (shopDocs.isEmpty) return const Text("No shops found.");

                  return Wrap(
                    spacing: 8.0,
                    children: shopDocs.map((doc) {
                      final shopName = doc['name'].toString();
                      final isSelected = _selectedShops.contains(shopName);
                      return FilterChip(
                        label: Text(shopName),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedShops.add(shopName);
                            } else {
                              _selectedShops.remove(shopName);
                            }
                          });
                        },
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      icon: Icon(_isEditMode ? Icons.save : Icons.person_add),
                      label: Text(
                        _isEditMode ? 'Update Employee' : 'Add Employee',
                      ),
                      onPressed: _submit,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
