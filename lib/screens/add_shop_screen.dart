import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddShopScreen extends StatefulWidget {
  const AddShopScreen({super.key});

  @override
  State<AddShopScreen> createState() => _AddShopScreenState();
}

class _AddShopScreenState extends State<AddShopScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  bool _isLoading = false;

  void _submitShop() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isLoading = true);

  final shopData = {
      'name': _nameController.text.trim(),
      'location': _locationController.text.trim(),
      'employees': [],
      'createdAt': Timestamp.now(),
      'isDeleted': false,
      'isOpen': true, // ✅ Add this line to fix the error
    };
  try {
    await FirebaseFirestore.instance.collection('shops').add(shopData);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shop added successfully')),
      );
      Navigator.of(context).pop();
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding shop: $e')),
      );
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Shop'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Shop Name'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter shop name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: 'Location'),
                validator: (value) => value == null || value.isEmpty
                    ? 'Enter shop location'
                    : null,
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Add Shop'),
                      onPressed: _submitShop,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
