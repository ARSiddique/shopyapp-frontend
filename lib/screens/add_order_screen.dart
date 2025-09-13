// lib/screens/add_order_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/app_data_provider.dart';

class AddOrderScreen extends StatefulWidget {
  const AddOrderScreen({
    super.key,
    required this.shopName,
    required this.wholesalerName,
  });

  final String shopName;
  final String wholesalerName;

  @override
  State<AddOrderScreen> createState() => _AddOrderScreenState();
}

class _AddOrderScreenState extends State<AddOrderScreen> {
  final _formKey = GlobalKey<FormState>();

  double _orderAmount = 0.0;
  double _orderAmount2 = 0.0;

  bool _isSubmitting = false;
  bool _isUploading = false;
  String? _localInvoiceName;
  Uint8List? _invoiceBytes;

  // --------- Helpers ---------
  Future<void> _pickInvoice() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.camera);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (!mounted) return;
      setState(() {
        _invoiceBytes = bytes;
        _localInvoiceName = x.name;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to pick invoice: $e')));
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
      final url = await app.uploadInvoiceBytes(
        _invoiceBytes!,
        shopName: shopName,
        wholesaler: wholesalerName,
      );
      return url;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Invoice upload failed: $e')));
      return null;
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();

    final isFormValid =
        _orderAmount > 0 && !_isSubmitting && !_isUploading;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Order')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Shop (read-only)
              TextFormField(
                readOnly: true,
                initialValue: widget.shopName,
                decoration: const InputDecoration(
                  labelText: 'Shop',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Wholesaler (read-only)
              TextFormField(
                readOnly: true,
                initialValue: widget.wholesalerName,
                decoration: const InputDecoration(
                  labelText: 'Wholesaler',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Amount 1 (required)
              TextFormField(
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Invoice Amount',
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) =>
                    setState(() => _orderAmount = double.tryParse(val.trim()) ?? 0),
                validator: (v) =>
                    (double.tryParse(v?.trim() ?? '') ?? 0) <= 0
                        ? 'Invalid amount'
                        : null,
              ),
              const SizedBox(height: 12),

              // Amount 2 (optional)
              TextFormField(
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Invoice2 Amount (optional)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) =>
                    setState(() => _orderAmount2 = double.tryParse(val.trim()) ?? 0),
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
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
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

    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isSubmitting = true);
    try {
      String? invoiceUrl;
      if (_invoiceBytes != null) {
        invoiceUrl = await _uploadInvoiceIfAny(
          app,
          widget.shopName,
          widget.wholesalerName,
        );
      }

      final err = await app.placeOrderUniquePerDay(
        shopName: widget.shopName,
        wholesalerId: widget.wholesalerName,   // fallback id = name
        wholesalerName: widget.wholesalerName,
        amount: _orderAmount,
        amount2: _orderAmount2 == 0 ? null : _orderAmount2,
        note: null,
        invoiceUrl: invoiceUrl,
      );

      if (err != null) {
        messenger.showSnackBar(SnackBar(content: Text(err)));
        return;
      }

      messenger.showSnackBar(const SnackBar(content: Text('Order submitted')));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
