// lib/screens/add_sale_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/app_data_provider.dart';

class AddSaleScreen extends StatefulWidget {
  final Map<String, dynamic>? existingSale; // edit flow
  final String? shopName;                   // optional: lock to a shop

  const AddSaleScreen({super.key, this.existingSale, this.shopName});

  @override
  State<AddSaleScreen> createState() => _AddSaleScreenState();
}

class _AddSaleScreenState extends State<AddSaleScreen> {
  final _formKey = GlobalKey<FormState>();

  final _cashC = TextEditingController();
  final _cardC = TextEditingController();
  final _otherC = TextEditingController();

  bool _loading = false;
  String? _selectedShop;

  /// 'today' | 'yesterday'
  String _dayChoice = 'today';

  @override
  void initState() {
    super.initState();
    _prefillIfEditing();
  }

  void _prefillIfEditing() {
    if (widget.existingSale == null) return;
    final s = widget.existingSale!;
    _selectedShop = (s['shop'] ?? '').toString();

    _cashC.text = _numToText(s['cash']);
    _cardC.text = _numToText(s['card']);
    _otherC.text = _numToText(s['other']);

    // Decide today/yesterday by createdAt
    final dt = s['createdAt'] is DateTime
        ? s['createdAt'] as DateTime
        : (s['createdAt'] is Timestamp
            ? (s['createdAt'] as Timestamp).toDate()
            : DateTime.now());
    final today = DateTime.now();
    final base = DateTime(today.year, today.month, today.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == base) {
      _dayChoice = 'today';
    } else if (d == base.subtract(const Duration(days: 1))) {
      _dayChoice = 'yesterday';
    } else {
      // edit for older day → we keep createdAt on update, just leave toggle on 'today' visually
      _dayChoice = 'today';
    }
  }

  @override
  void dispose() {
    _cashC.dispose();
    _cardC.dispose();
    _otherC.dispose();
    super.dispose();
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();
    final me = app.loggedInUser ?? {};
    final role = (me['role'] ?? '').toString().toLowerCase();

    // Build shops list
    final allShops = app.shops
        .where((s) => (s['isDeleted'] ?? false) != true)
        .map((s) => (s['name'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList()
      ..sort();

    final assigned = (me['assignedShops'] as List? ?? [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toSet();

    // Admin/Manager → all shops; Employee → assigned only
    final shopOptions = (role == 'admin' || role == 'manager')
        ? allShops
        : allShops.where((s) => assigned.contains(s)).toList();

    // Lock by widget.shopName if provided
    final bool lockShop = widget.shopName?.isNotEmpty == true;
    if (lockShop && (shopOptions.contains(widget.shopName) || (role == 'admin' || role == 'manager'))) {
      _selectedShop = widget.shopName;
    }

    // Default selected if still null
    _selectedShop ??= (widget.existingSale?['shop']?.toString().isNotEmpty == true)
        ? widget.existingSale!['shop'].toString()
        : (shopOptions.isNotEmpty ? shopOptions.first : null);

    final isEditing = widget.existingSale != null;

    final total = _parse(_cashC.text) + _parse(_cardC.text) + _parse(_otherC.text);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Sale' : 'Add Sale'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: shopOptions.isEmpty && !isEditing
            ? const Center(child: Text('No shop available to add a sale.'))
            : Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // Shop (dropdown or locked display)
                    if (!lockShop)
                      DropdownButtonFormField<String>(
                        value: (_selectedShop != null && shopOptions.contains(_selectedShop))
                            ? _selectedShop
                            : (shopOptions.isNotEmpty ? shopOptions.first : null),
                        items: shopOptions
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedShop = v),
                        decoration: const InputDecoration(
                          labelText: 'Shop',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Select a shop' : null,
                      )
                    else
                      TextFormField(
                        readOnly: true,
                        initialValue: widget.shopName,
                        decoration: const InputDecoration(
                          labelText: 'Shop',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Today / Yesterday
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Today'),
                            selected: _dayChoice == 'today',
                            onSelected: (_) => setState(() => _dayChoice = 'today'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Yesterday'),
                            selected: _dayChoice == 'yesterday',
                            onSelected: (_) => setState(() => _dayChoice = 'yesterday'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _amountField(_cashC, 'Cash'),
                    const SizedBox(height: 12),
                    _amountField(_cardC, 'Card'),
                    const SizedBox(height: 12),
                    _amountField(_otherC, 'Other'),

                    const SizedBox(height: 16),
                    _totalBar(total),

                    const SizedBox(height: 18),
                    _loading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton.icon(
                            icon: Icon(isEditing ? Icons.save : Icons.add),
                            label: Text(isEditing ? 'Update Sale' : 'Add Sale'),
                            onPressed: () => isEditing ? _updateSale() : _submitSale(),
                          ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _amountField(TextEditingController c, String label) {
    return TextFormField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixText: 'Rs. ',
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return null; // optional fields
        final d = double.tryParse(v);
        if (d == null) return 'Invalid number';
        if (d < 0) return 'Must be ≥ 0';
        return null;
      },
      onChanged: (_) => setState(() {}), // refresh total
    );
  }

  Widget _totalBar(double total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          const Icon(Icons.summarize_outlined),
          const SizedBox(width: 10),
          const Text('Total', style: TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('Rs. ${total.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // --------------- Logic ----------------

  DateTime _selectedDate() {
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day);
    return _dayChoice == 'today' ? base : base.subtract(const Duration(days: 1));
  }

  (DateTime, DateTime) _dayBounds(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (start, end);
  }

  double _parse(String s) => double.tryParse(s.trim()) ?? 0.0;
  String _numToText(dynamic n) {
    if (n == null) return '';
    final d = (n is num) ? n.toDouble() : double.tryParse('$n') ?? 0.0;
    return (d == 0) ? '' : d.toStringAsFixed(d % 1 == 0 ? 0 : 2);
  }

  Future<void> _submitSale() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedShop == null || _selectedShop!.isEmpty) {
      _snack('Select a shop');
      return;
    }

    final app = context.read<AppDataProvider>();
    final me = app.loggedInUser ?? {};
    final name = (me['name'] ?? '').toString();

    final cash = _parse(_cashC.text);
    final card = _parse(_cardC.text);
    final other = _parse(_otherC.text);
    final total = cash + card + other;

    setState(() => _loading = true);
    try {
      final chosen = _selectedDate();
      final (from, to) = _dayBounds(chosen);

      // ✅ One-sale-per-shop-per-day check
      final dupQ = FirebaseFirestore.instance
          .collection('sales')
          .where('shop', isEqualTo: _selectedShop)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .where('createdAt', isLessThan: Timestamp.fromDate(to))
          .limit(1);

      final dupSnap = await dupQ.get();
      if (dupSnap.docs.isNotEmpty) {
        _snack(
          'Sale already exists for ${_selectedShop!} on ${DateFormat('dd MMM, yyyy').format(from)}',
        );
        setState(() => _loading = false);
        return;
      }

      // Set createdAt at midday of chosen date (for consistent date filtering)
      final createdAt = DateTime(chosen.year, chosen.month, chosen.day, 12, 0);

      final data = {
        'shop': _selectedShop,
        'employee': name,
        'cash': cash,
        'card': card,
        'other': other,
        'total': total,
        'createdAt': Timestamp.fromDate(createdAt),
      };

      // Direct write (so createdAt stays what we set)
      final doc = await FirebaseFirestore.instance.collection('sales').add(data);

      // Refresh UI
      await app.fetchSales();

      _snack('Sale added (ID: ${doc.id})', ok: true);
      if (mounted) Navigator.pop(context);
    } on FirebaseException catch (e) {
      // If you get index error: create composite index on (shop ==, createdAt ASC)
      _snack('Error: ${e.message}');
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateSale() async {
    if (!_formKey.currentState!.validate()) return;

    final sale = widget.existingSale ?? {};
    final saleId = (sale['id'] ?? '').toString();
    if (saleId.isEmpty) {
      _snack('Missing sale ID');
      return;
    }

    final app = context.read<AppDataProvider>();

    final cash = _parse(_cashC.text);
    final card = _parse(_cardC.text);
    final other = _parse(_otherC.text);
    final total = cash + card + other;

    setState(() => _loading = true);
    try {
      // Keep original createdAt on edit
      final updates = {
        'shop': _selectedShop ?? sale['shop'],
        'cash': cash,
        'card': card,
        'other': other,
        'total': total,
        'editedAt': Timestamp.now(),
      };
      await FirebaseFirestore.instance.collection('sales').doc(saleId).update(updates);

      await app.fetchSales();
      _snack('Sale updated', ok: true);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool ok = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ok ? Colors.green : null,
      ),
    );
  }
}
