// lib/screens/add_employee_and_access_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String _selectedRole = 'employee';
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isEditMode = false;

  Map<String, dynamic>? _loggedInUser;
  bool _isAssigningToSelf = false;

  @override
  void initState() {
    super.initState();

    // Run after the first frame so context/route safely available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final app = context.read<AppDataProvider>();
      _loggedInUser = app.loggedInUser;

      // Route arguments safely after first frame
      final args = ModalRoute.of(context)?.settings.arguments;
      _isAssigningToSelf = args == 'assignMyself';

      // ----- EDIT MODE -----
      if (widget.existingEmployee != null) {
        final emp = widget.existingEmployee!;
        setState(() {
          _isEditMode = true;
          _nameController.text =
              (emp['name'] ?? '').toString();
          _phoneController.text =
              (emp['phone'] ?? '').toString();
          _emailController.text =
              (emp['email'] ?? '').toString();
          _selectedRole =
              (emp['role'] ?? 'employee').toString().toLowerCase();
          _passwordController.text =
              (emp['password'] ?? emp['loginCode'] ?? '').toString();
        });
        return;
      }

      // ----- SELF-ASSIGN MODE (update self) -----
      if (_isAssigningToSelf && _loggedInUser != null) {
        setState(() {
          _isEditMode = true;
          _nameController.text =
              (_loggedInUser!['name'] ?? '').toString();
          _phoneController.text =
              (_loggedInUser!['phone'] ?? '').toString();
          _emailController.text =
              (_loggedInUser!['email'] ?? '').toString();
          _selectedRole =
              (_loggedInUser!['role'] ?? 'employee').toString().toLowerCase();
          _passwordController.text =
              (_loggedInUser!['password'] ??
                      _loggedInUser!['loginCode'] ??
                      '')
                  .toString();
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final app = Provider.of<AppDataProvider>(context, listen: false);

      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      final email = _emailController.text.trim();
      final role = _selectedRole.toLowerCase().trim();
      final pass = _passwordController.text.trim();

      final baseData = {
        'name': name,
        'phone': phone,
        'email': email,
        'role': role.isEmpty ? 'employee' : role,
        'assignedShops': <String>[],
        'updatedAt': Timestamp.now(),
      };

      // --------------------------
      // EDIT MODE
      // --------------------------
      if (_isEditMode) {
        final String id = (widget.existingEmployee?['uid'] ??
                _loggedInUser?['uid'] ??
                '')
            .toString();
        if (id.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Missing user ID for edit'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        final empRef =
            FirebaseFirestore.instance.collection('employees').doc(id);
        final usrRef =
            FirebaseFirestore.instance.collection('users').doc(id);

        final empSnap = await empRef.get();
        if (empSnap.exists) {
          await empRef.update(baseData);
        } else {
          await empRef.set({
            ...baseData,
            'createdAt': Timestamp.now(),
            'uid': id,
          });
        }

        final usrSnap = await usrRef.get();
        if (usrSnap.exists) {
          await usrRef.update(baseData);
        } else {
          await usrRef.set({
            ...baseData,
            'createdAt': Timestamp.now(),
            'uid': id,
          });
        }

        // Optional: password/loginCode update
        if (pass.isNotEmpty) {
          await empRef.update({'password': pass, 'loginCode': pass});
          await usrRef.update({'password': pass, 'loginCode': pass});

          try {
            final current = FirebaseAuth.instance.currentUser;
            if (current != null && current.uid == id) {
              await current.updatePassword(pass);
            } else if (email.isNotEmpty) {
              await FirebaseAuth.instance
                  .sendPasswordResetEmail(email: email);
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('Auth password update failed: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }

        // Refresh local caches
        await app.fetchEmployees();
        await app.fetchUsers();

        if (!mounted) return;
        Navigator.pop(context);
        return;
      }

      // --------------------------
      // CREATE MODE
      // --------------------------
      String newUid;

      try {
        final cred =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: pass,
        );
        if (cred.user == null) {
          throw 'Auth user not created';
        }
        newUid = cred.user!.uid;
      } on FirebaseAuthException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Auth create failed: ${e.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final empRef =
          FirebaseFirestore.instance.collection('employees').doc(newUid);
      final usrRef =
          FirebaseFirestore.instance.collection('users').doc(newUid);

      final createPayload = {
        ...baseData,
        'uid': newUid,
        'createdAt': Timestamp.now(),
        'password': pass,
        'loginCode': pass,
      };

      // 2) Write to Firestore (employees + users)
      await Future.wait([
        empRef.set(createPayload),
        usrRef.set(createPayload),
      ]);

      // 3) Refresh cache
      await app.fetchEmployees();
      await app.fetchUsers();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Employee created successfully'),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _isEditMode;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Employee' : 'Add Employee'),
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
                    "You’re updating your info. Shops are assigned from your employee card.",
                    style: TextStyle(color: Colors.deepPurple),
                  ),
                ),
              TextFormField(
                controller: _nameController,
                decoration:
                    const InputDecoration(labelText: 'Full name'),
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                readOnly: _isAssigningToSelf,
                validator: (v) =>
                    (v == null || v.trim().isEmpty)
                        ? 'Enter name'
                        : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration:
                    const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly
                ],
                textInputAction: TextInputAction.next,
                readOnly: _isAssigningToSelf,
                validator: (v) =>
                    (v == null || v.trim().isEmpty)
                        ? 'Enter phone'
                        : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration:
                    const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                readOnly: _isAssigningToSelf,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Email is required';
                  }
                  if (!v.contains('@')) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // 🔐 Password field: add + edit (edit me optional)
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                keyboardType: TextInputType.visiblePassword,
                decoration: InputDecoration(
                  labelText: isEditing
                      ? 'New Password / Login Code (optional)'
                      : 'Password / Login Code',
                  suffixIcon: IconButton(
                    onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword),
                    icon: Icon(_obscurePassword
                        ? Icons.visibility
                        : Icons.visibility_off),
                  ),
                ),
                validator: (v) {
                  if (!isEditing &&
                      (v == null || v.trim().length < 4)) {
                    return 'Minimum 4 characters';
                  }
                  if (isEditing &&
                      v != null &&
                      v.isNotEmpty &&
                      v.length < 4) {
                    return 'Minimum 4 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: ['employee', 'manager']
                        .contains(_selectedRole)
                    ? _selectedRole
                    : 'employee',
                items: const [
                  DropdownMenuItem(
                      value: 'employee',
                      child: Text('Employee')),
                  DropdownMenuItem(
                      value: 'manager', child: Text('Manager')),
                ],
                onChanged: _isAssigningToSelf
                    ? null
                    : (val) {
                        if (val != null) {
                          setState(() => _selectedRole = val);
                        }
                      },
                decoration:
                    const InputDecoration(labelText: 'Role'),
              ),
              const SizedBox(height: 24),

              _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : ElevatedButton.icon(
                      icon: Icon(isEditing
                          ? Icons.save
                          : Icons.person_add),
                      label: Text(isEditing
                          ? 'Update'
                          : 'Add Employee'),
                      onPressed: _submit,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
