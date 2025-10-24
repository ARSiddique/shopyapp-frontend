// lib/screens/add_order_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/app_data_provider.dart';

class AddOrderScreen extends StatefulWidget {
  /// If provided → we are receiving/updating an existing order.
  /// If null      → we will create a new order directly in "Received" state.
  final String? orderId;

  /// Read-only labels shown on the form (always required for this screen).
  final String shopName;
  final String wholesalerName;

  /// Optional initial payload (not strictly required by this screen,
  /// but kept for convenience if you pass prefilled values).
  final Map<String, dynamic>? initial;

  const AddOrderScreen({
    super.key,
    this.orderId,
    required this.shopName,
    required this.wholesalerName,
    this.initial,
  });

  @override
  State<AddOrderScreen> createState() => _AddOrderScreenState();
}

class _AddOrderScreenState extends State<AddOrderScreen> {
  final _formKey = GlobalKey<FormState>();

  double? _invoice1;
  double? _invoice2;

  bool _isSubmitting = false;
  bool _isUploading = false;
  String? _localInvoiceName;
  Uint8List? _invoiceBytes;

  // ---------- Helpers ----------
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

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();
    final canSubmit = !_isSubmitting && !_isUploading;

    final isEditExisting = (widget.orderId != null && widget.orderId!.isNotEmpty);
    final title = isEditExisting ? 'Receive Order' : 'Create & Receive Order';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
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

              // Invoice 1 (required)
              TextFormField(
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Invoice Amount',
                  hintText: 'e.g. 1250.00',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final d = double.tryParse(v?.trim() ?? '');
                  if (d == null || d <= 0) return 'Invalid amount';
                  return null;
                },
                onSaved: (v) => _invoice1 = double.tryParse(v!.trim()),
              ),
              const SizedBox(height: 12),

              // Invoice 2 (optional)
              TextFormField(
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Invoice 2 Amount (optional)',
                  border: OutlineInputBorder(),
                ),
                onSaved: (v) {
                  final t = (v == null || v.trim().isEmpty)
                      ? null
                      : double.tryParse(v.trim());
                  _invoice2 = t;
                },
              ),
              const SizedBox(height: 16),

              // Invoice photo (optional)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.receipt_long),
                      label: Text(
                        _invoiceBytes == null
                            ? 'Attach Invoice Photo (optional)'
                            : 'Attached: ${_localInvoiceName ?? 'invoice.jpg'}',
                      ),
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
                      : const Icon(Icons.check_circle),
                  label: Text(_isSubmitting
                      ? 'Submitting…'
                      : (isEditExisting ? 'Mark as Received' : 'Create & Receive')),
                  onPressed: canSubmit ? () => _submit(app, isEditExisting) : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(AppDataProvider app, bool isEditExisting) async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSubmitting = true);

    try {
      // Upload photo if any
      final invoiceUrl = await _uploadInvoiceIfAny(
        app,
        widget.shopName,
        widget.wholesalerName,
      );

      if (isEditExisting) {
        // ✅ Update existing order and mark as Received
        await app.receiveOrderWithInvoices(
          orderId: widget.orderId!, // safe: isEditExisting == true
          shopName: widget.shopName,
          wholesalerName: widget.wholesalerName,
          invoice1: _invoice1,
          invoice2: _invoice2,
          invoiceUrl: invoiceUrl,
          note: null,
        );
      } else {
        // ✅ Create a fresh order and mark it as Received immediately
        final dayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
        await app.addOrder({
          'shopName'      : widget.shopName,
          'wholesalerName': widget.wholesalerName,
          'amount'        : _invoice1 ?? 0.0,
          if (_invoice2 != null) 'amount2': _invoice2,
          if (invoiceUrl != null && invoiceUrl.isNotEmpty) 'invoiceUrl': invoiceUrl,
          'status'        : 'Received',
          'note'          : '',
          'dayKey'        : dayKey,
          // createdAt/updatedAt will be set inside addOrder()
        });
      }

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(isEditExisting
            ? 'Order marked as Received'
            : 'Order created in Received state')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
