import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/app_data_provider.dart';
import 'shop_selection_screen.dart';

class AddSaleScreen extends StatefulWidget {
  final String? shopName; // prefill for new entry or when coming from Sales screen
  final Map<String, dynamic>? existingSale; // edit mode

  const AddSaleScreen({super.key, this.shopName, this.existingSale});

  @override
  State<AddSaleScreen> createState() => _AddSaleScreenState();
}

class _AddSaleScreenState extends State<AddSaleScreen> {
  final _formKey = GlobalKey<FormState>();

  // controllers
  final _cashC = TextEditingController();
  final _cardC = TextEditingController();
  final _otherC = TextEditingController();
  String? _selectedShop;

  bool _isSaving = false;
  bool get isEdit => widget.existingSale != null;

  @override
  void initState() {
    super.initState();

    // Prefill edit
    if (isEdit) {
      final s = widget.existingSale!;
      _selectedShop = s['shop']?.toString();
      _cashC.text = (s['cash'] ?? 0).toString();
      _cardC.text = (s['card'] ?? 0).toString();
      _otherC.text = (s['other'] ?? 0).toString();
    } else {
      // Prefill new
      _selectedShop = widget.shopName;
    }
  }

  @override
  void dispose() {
    _cashC.dispose();
    _cardC.dispose();
    _otherC.dispose();
    super.dispose();
  }

  double _toD(String s) => double.tryParse(s.trim().isEmpty ? '0' : s.trim()) ?? 0.0;

  Future<bool> _confirmExit() async {
    if (Platform.isIOS) {
      final res = await showCupertinoDialog<bool>(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Exit'),
          content: const Text('Do you want to leave this screen?'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Leave'),
            ),
          ],
        ),
      );
      return res ?? false;
    } else {
      final res = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Exit'),
          content: const Text('Do you want to leave this screen?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Leave')),
          ],
        ),
      );
      return res ?? false;
    }
  }

  Future<bool> _confirmSubmit(double total) async {
    final msg = 'Submit sale of Rs. ${total.toStringAsFixed(0)} for "${_selectedShop ?? ''}"?';
    if (Platform.isIOS) {
      final res = await showCupertinoDialog<bool>(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Confirm'),
          content: Text(msg),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes'),
            ),
          ],
        ),
      );
      return res ?? false;
    } else {
      final res = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Confirm'),
          content: Text(msg),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
          ],
        ),
      );
      return res ?? false;
    }
  }

  Future<bool> _alreadyHasSaleToday({
    required String shop,
    String? ignoreSaleId, // in edit mode ignore itself
  }) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final snap = await FirebaseFirestore.instance
        .collection('sales')
        .where('shop', isEqualTo: shop)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end))
        .get();

    if (snap.docs.isEmpty) return false;
    if (ignoreSaleId == null) return true;

    // editing: allow if only this record exists for today
    final others = snap.docs.where((d) => d.id != ignoreSaleId).toList();
    return others.isNotEmpty;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final app = context.read<AppDataProvider>();
    final user = app.loggedInUser ?? {};
    final role = (user['role'] ?? 'employee').toString().toLowerCase();

    final shop = _selectedShop?.trim();
    if (shop == null || shop.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a shop')),
      );
      return;
    }

    final cash = _toD(_cashC.text);
    final card = _toD(_cardC.text);
    final other = _toD(_otherC.text);
    final total = cash + card + other;

    final ok = await _confirmSubmit(total);
    if (!ok) return;

    setState(() => _isSaving = true);

    try {
      // One sale per shop per day (NEW) — in edit, ignore own id
      final ignoreId = isEdit ? widget.existingSale!['id']?.toString() : null;
      final exists = await _alreadyHasSaleToday(shop: shop, ignoreSaleId: ignoreId);
      if (!isEdit && exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sale already exists for this shop today'),
            backgroundColor: Colors.red, // 🔴 as requested
          ),
        );
        setState(() => _isSaving = false);
        return;
      }

      if (isEdit) {
        // UPDATE
        final id = widget.existingSale!['id'].toString();
        await app.updateSale(id, {
          'shop': shop,
          'cash': cash,
          'card': card,
          'other': other,
          'total': total,
          'editedAt': Timestamp.now(),
        });
      } else {
        // ADD
        await app.addSale({
          'shop': shop,
          'cash': cash,
          'card': card,
          'other': other,
          'total': total,
          'employee': (user['name'] ?? '').toString(),
          'addedBy': (user['name'] ?? '').toString(),
          'creatorUid': (user['uid'] ?? '').toString(),
          'createdAt': Timestamp.now(), // provider will normalize locally
        });
      }

      if (!mounted) return;

      // Go back smartly:
      // Employee: if multiple shops → go to ShopSelection; if one → confirm exit to close
      // Admin/Manager: just pop
      final assignedShops = (user['assignedShops'] ?? const <String>[]).cast<String>();
      if (role == 'employee') {
        if (assignedShops.length > 1) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const ShopSelectionScreen()),
            (r) => r.isFirst,
          );
        } else {
          Navigator.of(context).pop(); // go back to previous
        }
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _switchShopIfAllowed() async {
    final app = context.read<AppDataProvider>();
    final user = app.loggedInUser ?? {};
    final role = (user['role'] ?? 'employee').toString().toLowerCase();
    final assignedShops = (user['assignedShops'] ?? const <String>[]).cast<String>();

    if (role == 'employee' && assignedShops.length > 1) {
      // Go to selection
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ShopSelectionScreen()),
      );
    }
  }

  Future<bool> _handleBack() async {
    final app = context.read<AppDataProvider>();
    final user = app.loggedInUser ?? {};
    final role = (user['role'] ?? 'employee').toString().toLowerCase();
    final assigned = (user['assignedShops'] ?? const <String>[]).cast<String>();

    if (role == 'employee') {
      if (assigned.length > 1) {
        // back => go to shop selection
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ShopSelectionScreen()),
        );
        return false;
      } else {
        // back => ask exit
        return await _confirmExit();
      }
    }
    // admin/manager -> normal pop
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();
    final user = app.loggedInUser ?? {};
    final role = (user['role'] ?? 'employee').toString().toLowerCase();

    final allShops = app.shops.where((s) => s['isDeleted'] != true).toList();
    final assigned = (user['assignedShops'] ?? const <String>[]).cast<String>();

    // Employee shop options limited to assigned; admin/manager can pick any
    final shopNames = role == 'employee'
        ? assigned
        : allShops.map((s) => (s['name'] ?? '').toString()).where((e) => e.isNotEmpty).toList();

    final canSwitchShop = role == 'employee' && assigned.length > 1;

    // If employee has 0 shops
    if (role == 'employee' && shopNames.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('${(user['name'] ?? 'Unknown').toString().trim()} | ${role.toUpperCase()}'),
        ),
        body: const Center(
          child: Text(
            'No shop assigned',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    // Ensure a selected shop
    _selectedShop ??= (shopNames.isNotEmpty ? shopNames.first : null) ?? widget.shopName;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final ok = await _handleBack();
          if (ok && mounted) Navigator.of(context).maybePop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: false,
          title: Text(
            'Add Sale${isEdit ? " (Edit)" : ""} | ${_selectedShop ?? ""}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (canSwitchShop)
              TextButton.icon(
                onPressed: _switchShopIfAllowed,
                icon: const Icon(Icons.swap_horiz, color: Colors.white),
                label: const Text('Switch Shop', style: TextStyle(color: Colors.white)),
              ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  // Shop picker (admin/manager can change; employee sees read-only if 1 shop)
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Shop',
                      border: OutlineInputBorder(),
                    ),
                    child: role == 'employee'
                        ? Text(_selectedShop ?? '')
                        : DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _selectedShop,
                              items: shopNames
                                  .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                                  .toList(),
                              onChanged: (v) => setState(() => _selectedShop = v),
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _cashC,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
                    decoration: const InputDecoration(
                      labelText: 'Cash',
                      prefixIcon: Icon(Icons.payments_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter cash (0 if none)' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cardC,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
                    decoration: const InputDecoration(
                      labelText: 'Card',
                      prefixIcon: Icon(Icons.credit_card),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter card (0 if none)' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _otherC,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
                    decoration: const InputDecoration(
                      labelText: 'Other',
                      prefixIcon: Icon(Icons.more_horiz),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter other (0 if none)' : null,
                  ),
                  const SizedBox(height: 20),
                  _TotalPreview(
                    cash: _toD(_cashC.text),
                    card: _toD(_cardC.text),
                    other: _toD(_otherC.text),
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 24),
                  _isSaving
                      ? const Center(child: CircularProgressIndicator())
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: Icon(isEdit ? Icons.save : Icons.check_circle_outline),
                            label: Text(isEdit ? 'Update Sale' : 'Submit Sale'),
                            onPressed: _save,
                            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TotalPreview extends StatefulWidget {
  final double cash;
  final double card;
  final double other;
  final VoidCallback onChanged;

  const _TotalPreview({
    required this.cash,
    required this.card,
    required this.other,
    required this.onChanged,
  });

  @override
  State<_TotalPreview> createState() => _TotalPreviewState();
}

class _TotalPreviewState extends State<_TotalPreview> {
  @override
  Widget build(BuildContext context) {
    final total = widget.cash + widget.card + widget.other;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.summarize_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Total: Rs. ${total.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
          Text(DateFormat('dd MMM, yyyy  hh:mm a').format(DateTime.now())),
        ],
      ),
    );
  }
}
