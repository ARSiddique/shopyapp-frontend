// lib/screens/place_order_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

class PlaceOrderScreen extends StatefulWidget {
  /// If provided, these will be used and shown read-only.
  final String? shopName;
  final String? wholesalerName;
  final String? employeeName;

  const PlaceOrderScreen({
    super.key,
    this.shopName,
    this.wholesalerName,
    this.employeeName,
  });

  @override
  State<PlaceOrderScreen> createState() => _PlaceOrderScreenState();
}

class _PlaceOrderScreenState extends State<PlaceOrderScreen> {
  final _form = GlobalKey<FormState>();

  String? _shopName;
  String? _wholesalerName;
  String? _employeeName;
  String _itemName = '';
  double? _approxPrice;
  double? _qty;
  String? _note;

  @override
  void initState() {
    super.initState();
    final p = context.read<AppDataProvider>();
    _employeeName = widget.employeeName ?? p.loggedInUser?['name']?.toString();

    // Prefill from constructor if given
    _shopName = widget.shopName;
    _wholesalerName = widget.wholesalerName;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppDataProvider>();

    final shops = p.shops
        .map((s) => (s['name'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList();

    final wholesalers = p.wholesalers
        .map((w) => (w['name'] ?? '').toString())
        .where((w) => w.isNotEmpty)
        .toList();

    final shopLocked = (widget.shopName ?? '').isNotEmpty;
    final whLocked = (widget.wholesalerName ?? '').isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Place Order')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: ListView(
            children: [
              // Shop
              if (shopLocked)
                TextFormField(
                  readOnly: true,
                  initialValue: _shopName,
                  decoration: const InputDecoration(
                    labelText: 'Shop',
                    border: OutlineInputBorder(),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: _shopName,
                  decoration: const InputDecoration(labelText: 'Shop'),
                  items: shops
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _shopName = v),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Select shop' : null,
                ),
              const SizedBox(height: 12),

              // Wholesaler
              if (whLocked)
                TextFormField(
                  readOnly: true,
                  initialValue: _wholesalerName,
                  decoration: const InputDecoration(
                    labelText: 'Wholesaler',
                    border: OutlineInputBorder(),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: _wholesalerName,
                  decoration: const InputDecoration(labelText: 'Wholesaler'),
                  items: wholesalers
                      .map((w) => DropdownMenuItem(value: w, child: Text(w)))
                      .toList(),
                  onChanged: (v) => setState(() => _wholesalerName = v),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Select wholesaler' : null,
                ),
              const SizedBox(height: 12),

              // Item
              TextFormField(
                decoration: const InputDecoration(labelText: 'Item name'),
                onChanged: (v) => _itemName = v.trim(),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter item' : null,
              ),
              const SizedBox(height: 12),

              // Approx price
              TextFormField(
                decoration: const InputDecoration(labelText: 'Approx price'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) => _approxPrice = double.tryParse(v),
              ),
              const SizedBox(height: 12),

              // Quantity
              TextFormField(
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) => _qty = double.tryParse(v),
              ),
              const SizedBox(height: 12),

              // Note
              TextFormField(
                decoration: const InputDecoration(labelText: 'Note'),
                onChanged: (v) => _note = v,
              ),
              const SizedBox(height: 24),

              FilledButton(
                onPressed: () async {
                  if (!_form.currentState!.validate()) return;

                  final shop = _shopName!;
                  final wh = _wholesalerName!;
                  final emp = _employeeName ??
                      (p.loggedInUser?['email']?.toString() ?? '');

                  await p.placeSimpleOrder(
                    shopName: shop,
                    wholesalerName: wh,
                    employeeName: emp,
                    itemName: _itemName,
                    approxPrice: _approxPrice,
                    quantity: _qty,
                    note: _note,
                  );

                  if (context.mounted) Navigator.of(context).pop(true);
                },
                child: const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
