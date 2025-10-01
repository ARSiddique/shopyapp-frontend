import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/app_data_provider.dart';
import 'shop_selection_screen.dart';
import 'login_screen.dart';

class AddSaleScreen extends StatefulWidget {
  final Map<String, dynamic>? existingSale; // edit flow
  final String? shopName; // for employee/admin flow when shop preselected

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

  /// Employee uses 'today' | 'yesterday'
  String _dayChoice = 'today';

  /// Admin/Manager can pick any date (within configured range)
  DateTime? _pickedDate;

  bool get _isEmployee {
    final app = context.read<AppDataProvider>();
    final me = app.loggedInUser ?? {};
    final role = (me['role'] ?? '').toString().toLowerCase();
    return role == 'employee';
  }

  bool get _isAdminOrManager => !_isEmployee;

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

    final dt = _toDate(s['createdAt']);
    final d = _dayOnly(dt);

    // employee chip mapping (only used if employee)
    final base = _dayOnly(DateTime.now());
    if (d == base) {
      _dayChoice = 'today';
    } else if (d == base.subtract(const Duration(days: 1))) {
      _dayChoice = 'yesterday';
    }

    // admin/manager direct date
    _pickedDate = d;
  }

  @override
  void dispose() {
    _cashC.dispose();
    _cardC.dispose();
    _otherC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();
    final me = app.loggedInUser ?? {};

    // All active shop names (sorted)
    final allShops = app.shops
        .where((s) => (s['isDeleted'] ?? false) != true)
        .map((s) => (s['name'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList()
      ..sort();

    // Employee assigned shops
    final assigned = (me['assignedShops'] as List? ?? [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toSet();

    // Shop options per role
    final shopOptions =
        _isEmployee ? allShops.where((s) => assigned.contains(s)).toList() : allShops;

    // Decide selected shop
    _selectedShop ??= (widget.existingSale?['shop']?.toString().isNotEmpty == true)
        ? widget.existingSale!['shop'].toString()
        : (widget.shopName?.isNotEmpty == true
            ? widget.shopName
            : (shopOptions.isNotEmpty ? shopOptions.first : null));

    // Employee navigation/locking logic
    final hasMultipleAssigned = _isEmployee && shopOptions.length > 1;
    final shouldShowBackToSelection = hasMultipleAssigned;
    final appBarTitleShop = _selectedShop ?? '—';

    final isEditing = widget.existingSale != null;
    final total = _parse(_cashC.text) + _parse(_cardC.text) + _parse(_otherC.text);

    // PopScope controls back behavior for multi-shop employees
    final blockBackForSingleShopEmployee = _isEmployee && !hasMultipleAssigned;
    final interceptBackToSelection = shouldShowBackToSelection;
    final canPop = !(blockBackForSingleShopEmployee || interceptBackToSelection);

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (interceptBackToSelection) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ShopSelectionScreen()),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: shouldShowBackToSelection ? const BackButton() : null,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isEditing ? 'Edit Daily Sale' : 'Add Daily Sale'),
              Text(appBarTitleShop, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          actions: [
            if (hasMultipleAssigned)
              IconButton(
                tooltip: 'Switch shop',
                icon: const Icon(Icons.swap_horiz),
                onPressed: _goToShopSelection,
              ),
            IconButton(
              tooltip: 'Logout',
              icon: const Icon(Icons.logout),
              onPressed: _confirmLogout,
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: shopOptions.isEmpty && !isEditing
              ? const Center(child: Text('No shop available to add a sale.'))
              : Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      if (_isEmployee) _shopInfoCard(),
                      if (_isEmployee) const SizedBox(height: 12),

                      if (!_isEmployee)
                        DropdownButtonFormField<String>(
                          value: (_selectedShop != null &&
                                  shopOptions.contains(_selectedShop))
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
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Select a shop' : null,
                        ),

                      if (!_isEmployee) const SizedBox(height: 16),

                      // Role-aware date controls
                      if (_isEmployee) ...[
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
                      ] else ...[
                        OutlinedButton.icon(
                          icon: const Icon(Icons.event),
                          label: Text(_pickedDate == null
                              ? 'Pick sale date'
                              : DateFormat('dd MMM, yyyy').format(_pickedDate!)),
                          onPressed: () async {
                            final now = DateTime.now();
                            final fourMonthsAgo = DateTime(now.year, now.month - 4, now.day);
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _pickedDate ?? now,
                              firstDate: fourMonthsAgo, // ~4 months back
                              lastDate: now,            // up to today
                            );
                            if (picked != null) {
                              setState(() => _pickedDate = _dayOnly(picked));
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

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
                              onPressed:
                                  () => isEditing ? _updateSale() : _submitSale(),
                            ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  // ---------- Widgets ----------

  Widget _shopInfoCard() {
    final shop = _selectedShop ?? '';
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withAlpha(100),
        ),
      ),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.store)),
        title: const Text('Selected shop', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(shop.isEmpty ? '—' : shop),
        trailing: const Icon(Icons.check_circle, color: Colors.green),
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
        prefixText: r'$ ',
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return null;
        final d = double.tryParse(v);
        if (d == null) return 'Invalid number';
        if (d < 0) return 'Must be ≥ 0';
        return null;
      },
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _totalBar(double total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          const Icon(Icons.summarize_outlined),
          const SizedBox(width: 10),
          const Text('Total', style: TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('\$ ${total.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ---------- Navigation / Actions ----------

  void _goToShopSelection() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ShopSelectionScreen()),
    );
  }

  Future<void> _confirmLogout() async {
    final app = context.read<AppDataProvider>();
    final navigator = Navigator.of(context);

    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Logout?'),
            content:
                const Text('You will be signed out and returned to the login screen.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Logout'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    await app.logout();
    if (!mounted) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  // ---------- Logic ----------

  DateTime _selectedDate() {
    final now = DateTime.now();
    final base = _dayOnly(now);
    if (_isEmployee) {
      return _dayChoice == 'today' ? base : base.subtract(const Duration(days: 1));
    } else {
      return _pickedDate ?? base; // admin/manager free date
    }
  }

  (DateTime, DateTime) _dayBounds(DateTime date) {
    final start = _dayOnly(date);
    final end = start.add(const Duration(days: 1));
    return (start, end);
  }

  double _parse(String s) => double.tryParse(s.trim()) ?? 0.0;

  String _numToText(dynamic n) {
    if (n == null) return '';
    final d = (n is num) ? n.toDouble() : double.tryParse('$n') ?? 0.0;
    return (d == 0) ? '' : d.toStringAsFixed(d % 1 == 0 ? 0 : 2);
  }

  DateTime _toDate(dynamic raw) {
    if (raw is DateTime) return raw;
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
    return DateTime.now();
  }

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _submitSale() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);

    if (!_formKey.currentState!.validate()) return;
    if ((_selectedShop ?? '').isEmpty) {
      _showSnack(messenger, theme, 'Select a shop');
      return;
    }

    final app = context.read<AppDataProvider>();
    final me = app.loggedInUser ?? {};
    final role = (me['role'] ?? '').toString().toLowerCase();
    final isEmployee = role == 'employee';
    final name = (me['name'] ?? '').toString();

    final cash = _parse(_cashC.text);
    final card = _parse(_cardC.text);
    final other = _parse(_otherC.text);
    final total = cash + card + other;

    setState(() => _loading = true);
    try {
      final chosen = _selectedDate();
      final (from, _) = _dayBounds(chosen);
      final dayKey = app.dayKeyOf(chosen);

      // ❗ unique per shop per day
      final dupQ = FirebaseFirestore.instance
          .collection('sales')
          .where('shop', isEqualTo: _selectedShop)
          .where('dayKey', isEqualTo: dayKey)
          .limit(1);
      final dupSnap = await dupQ.get();
      if (dupSnap.docs.isNotEmpty) {
        if (!mounted) return;
        _showSnack(
          messenger,
          theme,
          'Sale already exists for ${_selectedShop!} on ${DateFormat('dd MMM, yyyy').format(from)}',
        );
        setState(() => _loading = false);
        return;
      }

      // store createdAt at a fixed noon time for that day
      final createdAt = DateTime(chosen.year, chosen.month, chosen.day, 12, 0);

      final data = {
        'shop': _selectedShop,
        'employee': name,
        'cash': cash,
        'card': card,
        'other': other,
        'total': total,
        'createdAt': Timestamp.fromDate(createdAt),
        'dayKey': dayKey,                 // for uniqueness & reporting
        'source': 'employee_manual',      // provenance
      };

      await FirebaseFirestore.instance.collection('sales').add(data);

      await app.fetchSales();
      if (!mounted) return;
      _showSnack(messenger, theme, 'Sale added', ok: true);

      // ----- role-aware navigation after submit -----
      if (isEmployee) {
        // Employee: reset so he can add next day’s sale if needed
        _cashC.clear();
        _cardC.clear();
        _otherC.clear();
        setState(() => _dayChoice = 'today');
      } else {
        // Admin/Manager → back
        navigator.pop();
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack(messenger, theme, 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateSale() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);

    if (!_formKey.currentState!.validate()) return;

    final sale = widget.existingSale ?? {};
    final saleId = (sale['id'] ?? '').toString();
    if (saleId.isEmpty) {
      _showSnack(messenger, theme, 'Missing sale ID');
      return;
    }

    final app = context.read<AppDataProvider>();

    final cash = _parse(_cashC.text);
    final card = _parse(_cardC.text);
    final other = _parse(_otherC.text);
    final total = cash + card + other;

    setState(() => _loading = true);
    try {
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
      if (!mounted) return;
      _showSnack(messenger, theme, 'Sale updated', ok: true);
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      _showSnack(messenger, theme, 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(
    ScaffoldMessengerState messenger,
    ThemeData theme,
    String msg, {
    bool ok = false,
  }) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ok ? Colors.green : theme.colorScheme.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
