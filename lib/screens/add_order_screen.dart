// lib/screens/add_order_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/app_data_provider.dart';

class AddOrderScreen extends StatefulWidget {
  const AddOrderScreen({super.key});

  @override
  State<AddOrderScreen> createState() => _AddOrderScreenState();
}

class _AddOrderScreenState extends State<AddOrderScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedShop;
  String _wholesalerName = '';
  double _orderAmount = 0.0;

  bool _isSubmitting = false;
  bool _isUploading = false;
  String? _localInvoiceName; // for UI preview
  Uint8List? _invoiceBytes;  // picked image bytes

  // --------- Helpers ---------
  Future<void> _pickInvoice() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? x = await picker.pickImage(source: ImageSource.camera);
      if (x == null) return;

      final bytes = await x.readAsBytes();
      if (!mounted) return;
      setState(() {
        _invoiceBytes = bytes;
        _localInvoiceName = x.name;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick invoice: $e')),
      );
    }
  }

  Future<String?> _uploadInvoiceIfAny(
    AppDataProvider app,
    String shopName,
    String wholesalerName,
  ) async {
    if (_invoiceBytes == null) return null;
    setState(() => _isUploading = true);
    try {
      // NOTE: assumes you already have this method in AppDataProvider
      final url = await app.uploadInvoiceBytes(
        _invoiceBytes!,
        shopName: shopName,
        wholesaler: wholesalerName,
      );
      return url;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invoice upload failed: $e')),
      );
      return null;
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();
    final me = app.loggedInUser ?? {};
    final role = (me['role'] ?? 'employee').toString().toLowerCase().trim();
    final isEmployee = role == 'employee';

    // 👇 Home/flow se selected shop ko prefer karo
    final selectedFromHome = app.selectedShopName;

    // visible shops list
    final assignedShops = isEmployee
        ? (me['assignedShops'] as List? ?? const [])
            .map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList()
        : app.shops
            .where((s) => (s['isDeleted'] ?? false) != true)
            .map((s) => (s['name'] ?? '').toString())
            .where((s) => s.isNotEmpty)
            .toList()
          ..sort();

    // auto-select only once
    _selectedShop ??= (selectedFromHome?.isNotEmpty == true)
        ? selectedFromHome
        : (assignedShops.isNotEmpty ? assignedShops.first : null);

    final isFormValid = (_selectedShop ?? '').isNotEmpty &&
        _wholesalerName.trim().isNotEmpty &&
        _orderAmount > 0 &&
        !_isSubmitting &&
        !_isUploading;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Order')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (!isEmployee)
                DropdownButtonFormField<String>(
                  value: _selectedShop,
                  decoration: const InputDecoration(
                    labelText: 'Select Shop',
                    border: OutlineInputBorder(),
                  ),
                  items: assignedShops
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedShop = v),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Please select a shop' : null,
                )
              else
                TextFormField(
                  readOnly: true,
                  initialValue: _selectedShop ?? '',
                  decoration: const InputDecoration(
                    labelText: 'Shop',
                    border: OutlineInputBorder(),
                  ),
                ),
              const SizedBox(height: 16),

              // Wholesaler
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Wholesaler Name',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                onChanged: (v) => setState(() => _wholesalerName = v),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter wholesaler name' : null,
              ),
              const SizedBox(height: 16),

              // Amount
              TextFormField(
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Order Amount',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
                onChanged: (val) {
                  final d = double.tryParse(val.trim());
                  setState(() => _orderAmount = d ?? 0);
                },
                validator: (v) =>
                    (double.tryParse(v?.trim() ?? '') ?? 0) <= 0 ? 'Invalid amount' : null,
              ),
              const SizedBox(height: 16),

              // Invoice attach
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.receipt_long),
                      label: Text(_invoiceBytes == null
                          ? 'Attach Invoice Photo'
                          : 'Attached: ${_localInvoiceName ?? 'invoice.jpg'}'),
                      onPressed: _isUploading ? null : _pickInvoice,
                    ),
                  ),
                  if (_isUploading) const SizedBox(width: 12),
                  if (_isUploading)
                    const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _isSubmitting
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                  label: Text(_isSubmitting ? 'Submitting…' : 'Submit Order'),
                  onPressed: isFormValid ? () => _submit(app) : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(AppDataProvider app) async {
    if (!_formKey.currentState!.validate()) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final shop = _selectedShop!.trim();
    final wholesaler = _wholesalerName.trim();

    setState(() => _isSubmitting = true);
    try {
      // 1) optional invoice upload
      String? invoiceUrl;
      if (_invoiceBytes != null) {
        invoiceUrl = await _uploadInvoiceIfAny(app, shop, wholesaler);
      }

      // 2) unique-per-day (uses your existing provider API)
      final err = await app.placeOrderUniquePerDay(
        shopName: shop,
        wholesalerId: wholesaler, // using name as fallback id
        wholesalerName: wholesaler,
        amount: _orderAmount,
        note: null,
        invoiceUrl: invoiceUrl,
      );

      if (err != null) {
        messenger.showSnackBar(SnackBar(content: Text(err)));
        return;
      }

      messenger.showSnackBar(const SnackBar(content: Text('Order submitted')));
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
