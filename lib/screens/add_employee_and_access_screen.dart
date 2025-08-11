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
  Future.microtask(() {
    final app = Provider.of<AppDataProvider>(context, listen: false);
    _loggedInUser = app.loggedInUser;

    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    _isAssigningToSelf = routeArgs == 'assignMyself';

    if (widget.existingEmployee != null) {
      // ✅ EDIT: existing employee se prefill
      final emp = widget.existingEmployee!;
      _isEditMode = true;
      _nameController.text  = (emp['name']  ?? '').toString();
      _phoneController.text = (emp['phone'] ?? '').toString();
      _emailController.text = (emp['email'] ?? '').toString();
      _selectedRole         = (emp['role']  ?? 'employee').toString().toLowerCase();

      // ⬇️ password/loginCode prefill (toggleable field me show hoga)
      final pwd = (emp['password'] ?? emp['loginCode'] ?? '').toString();
      _passwordController.text = pwd;

      setState(() {});
      return;
    }

    if (_isAssigningToSelf && _loggedInUser != null) {
      // ✅ EDIT: self-assign route se prefill
      _isEditMode = true;
      _nameController.text  = (_loggedInUser!['name']  ?? '').toString();
      _phoneController.text = (_loggedInUser!['phone'] ?? '').toString();
      _emailController.text = (_loggedInUser!['email'] ?? '').toString();
      _selectedRole         = (_loggedInUser!['role']  ?? 'employee').toString().toLowerCase();

      final pwd = (_loggedInUser!['password'] ?? _loggedInUser!['loginCode'] ?? '').toString();
      _passwordController.text = pwd;

      setState(() {});
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
    final name  = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final role  = _selectedRole.toLowerCase().trim();
    final pass  = _passwordController.text.trim();

    final baseData = {
      'name'          : name,
      'phone'         : phone,
      'email'         : email,
      'role'          : role,          // lowercase
      'assignedShops' : <String>[],    // edit screen par assignment nahi
      'updatedAt'     : Timestamp.now(),
    };

    if (_isEditMode) {
      // ✅ EDIT MODE
      final String id =
          (widget.existingEmployee?['uid'] ?? _loggedInUser?['uid'] ?? '').toString();
      if (id.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Missing user ID for edit'),
          backgroundColor: Colors.red,
        ));
        return;
      }

      final empRef = FirebaseFirestore.instance.collection('employees').doc(id);
      final usrRef = FirebaseFirestore.instance.collection('users').doc(id);

      // upsert employees/{id}
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

      // upsert users/{id}
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

      // 🔐 OPTIONAL: password/loginCode change agar user ne kuch enter kiya ho
      if (pass.isNotEmpty) {
        // Firestore me store (tumhare login-code flow ke liye)
        await empRef.update({'password': pass, 'loginCode': pass});
        await usrRef.update({'password': pass, 'loginCode': pass});

        // FirebaseAuth rules:
        // - Sirf current logged-in user apna password direct update kar sakta
        // - Dusre user ka change -> reset email
        try {
          final current = FirebaseAuth.instance.currentUser;
          if (current != null && current.uid == id) {
            await current.updatePassword(pass);
          } else if (email.isNotEmpty) {
            await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
            // (snackbar intentionally skip, agar show karna ho to yahan add karo)
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Auth password update failed: $e'),
              backgroundColor: Colors.red,
            ));
          }
        }
      }

      if (!mounted) return;
      // (confirmation snackbar off rakhna ho to comment rehne do)
      // ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      //   content: Text('Employee updated successfully'),
      // ));
      Navigator.pop(context);
      return;
    }

    // NOTE: create-mode yahan nahi include kiya, kyunki aap ne sirf edit block manga tha.
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
    );
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
                decoration: const InputDecoration(labelText: 'Full name'),
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                readOnly: _isAssigningToSelf,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.next,
                readOnly: _isAssigningToSelf,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter phone' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email (optional)'),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                readOnly: _isAssigningToSelf,
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
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off),
                  ),
                ),
                validator: (v) {
                  if (!isEditing && (v == null || v.trim().length < 4)) {
                    return 'Minimum 4 characters';
                  }
                  if (isEditing && v != null && v.isNotEmpty && v.length < 4) {
                    return 'Minimum 4 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: ['employee', 'manager'].contains(_selectedRole)
                    ? _selectedRole
                    : 'employee',
                items: const [
                  DropdownMenuItem(value: 'employee', child: Text('Employee')),
                  DropdownMenuItem(value: 'manager', child: Text('Manager')),
                ],
                onChanged: _isAssigningToSelf
                    ? null
                    : (val) {
                        if (val != null) setState(() => _selectedRole = val);
                      },
                decoration: const InputDecoration(labelText: 'Role'),
              ),
              const SizedBox(height: 24),

              // ⚠️ Shop assignment intentionally removed from here.
              // Use Employee Card → "Assign shops" button and AppDataProvider.updateShopAssignments().

              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      icon: Icon(isEditing ? Icons.save : Icons.person_add),
                      label: Text(isEditing ? 'Update' : 'Add Employee'),
                      onPressed: _submit,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
