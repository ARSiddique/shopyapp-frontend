import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

class AddShopScreen extends StatefulWidget {
  final Map<String, dynamic>? existingShop;

  const AddShopScreen({super.key, this.existingShop});

  @override
  State<AddShopScreen> createState() => _AddShopScreenState();
}

class _AddShopScreenState extends State<AddShopScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  bool _isOpen = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingShop != null) {
      _nameController.text = widget.existingShop!['name'] ?? '';
      _isOpen = widget.existingShop!['isOpen'] ?? true;
    }
  }

  Future<void> _submitShop() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final appData = Provider.of<AppDataProvider>(context, listen: false);

    final shopData = {
      'name': _nameController.text.trim(),
      'isOpen': _isOpen,
      'isDeleted': false,
      'updatedAt': DateTime.now(),
    };

    try {
      if (widget.existingShop != null) {
        // Update existing shop
        final docId = widget.existingShop!['id'];
        await FirebaseFirestore.instance
            .collection('shops')
            .doc(docId)
            .update(shopData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shop updated successfully')),
        );
      } else {
        // Add new shop
        shopData['createdAt'] = DateTime.now();
        await FirebaseFirestore.instance.collection('shops').add(shopData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shop added successfully')),
        );
      }

      await appData.fetchShops();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingShop != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Shop' : 'Add Shop'),
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
                decoration: const InputDecoration(
                  labelText: 'Shop Name',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Please enter a shop name'
                    : null,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Is Shop Open?'),
                value: _isOpen,
                onChanged: (val) => setState(() => _isOpen = val),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitShop,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  isEditing ? 'Update Shop' : 'Add Shop',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
