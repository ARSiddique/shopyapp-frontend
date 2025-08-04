import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

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

  Map<String, dynamic>? _loggedInUser;
  bool _isAssigningToSelf = false;

  @override
  void initState() {
    super.initState();

    Future.delayed(Duration.zero, () {
      final user = Provider.of<AppDataProvider>(
        context,
        listen: false,
      ).loggedInUser;
      _loggedInUser = user;

      final routeArgs = ModalRoute.of(context)?.settings.arguments;
      _isAssigningToSelf = routeArgs == 'assignMyself';

      if (_isAssigningToSelf) {
        setState(() {
          _isEditMode = true;
          _nameController.text = user?['name'] ?? '';
          _phoneController.text = user?['phone'] ?? '';
          _emailController.text = user?['email'] ?? '';
          _selectedRole = user?['role'] ?? 'employee';
          _selectedShops.addAll(
            (user?['assignedShops'] as List<dynamic>? ?? []).map(
              (e) => e.toString(),
            ),
          );
        });
      } else if (widget.existingEmployee != null) {
        final emp = widget.existingEmployee!;
        setState(() {
          _isEditMode = true;
          _nameController.text = emp['name'] ?? '';
          _phoneController.text = emp['phone'] ?? '';
          _emailController.text = emp['email'] ?? '';
          _selectedRole = emp['role'] ?? 'employee';
          _selectedShops.addAll(
            (emp['assignedShops'] as List<dynamic>? ?? []).map(
              (e) => e.toString(),
            ),
          );
        });
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // 🔒 Only one manager allowed
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

      // 🔸 Validate shop assignment for employees
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
        final id = widget.existingEmployee?['uid'] ?? _loggedInUser?['uid'];

        // 🧹 Remove from old shops
        final oldShops = widget.existingEmployee?['assignedShops'] ?? [];
        for (String shopName in oldShops) {
          final query = await FirebaseFirestore.instance
              .collection('shops')
              .where('name', isEqualTo: shopName)
              .limit(1)
              .get();
          if (query.docs.isNotEmpty) {
            final shopDoc = query.docs.first.reference;
            await shopDoc.update({
              'employees': FieldValue.arrayRemove([
                _nameController.text.trim(),
              ]),
            });
          }
        }

        // 📝 Update employee and user documents
        final empRef = FirebaseFirestore.instance
            .collection('employees')
            .doc(id);
        final userRef = FirebaseFirestore.instance.collection('users').doc(id);

        final empSnap = await empRef.get();
        if (!empSnap.exists) {
          await empRef.set(employeeData);
        } else {
          await empRef.update(employeeData);
        }

        final userSnap = await userRef.get();
        if (!userSnap.exists) {
          await userRef.set(employeeData);
        } else {
          await userRef.update(employeeData);
        }

        // 🔄 Re-add to new shops
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
                'employees': FieldValue.arrayUnion([
                  _nameController.text.trim(),
                ]),
              });
            }
          }
        }
      } else {
        // 🔐 Create user and save both records
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

        // 🔄 Add to shops for new employee
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
                'employees': FieldValue.arrayUnion([
                  _nameController.text.trim(),
                ]),
              });
            }
          }
        }
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
              if (_isAssigningToSelf)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    "You're assigning shops to yourself. Name, email, and login info are locked.",
                    style: TextStyle(color: Colors.deepPurple),
                  ),
                ),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                readOnly: _isAssigningToSelf,
                validator: (val) =>
                    val == null || val.isEmpty ? 'Enter name' : null,
              ),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                readOnly: _isAssigningToSelf,
                validator: (val) =>
                    val == null || val.isEmpty ? 'Enter phone' : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                readOnly: _isAssigningToSelf,
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
                value: ['employee', 'manager'].contains(_selectedRole)
                    ? _selectedRole
                    : null,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'employee', child: Text('Employee')),
                  DropdownMenuItem(value: 'manager', child: Text('Manager')),
                ],
                onChanged: (_isAssigningToSelf || _selectedRole == 'admin')
                    ? null
                    : (val) {
                        if (val != null) setState(() => _selectedRole = val);
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
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
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
