// lib/screens/add_sale_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/app_data_provider.dart';
import 'shop_selection_screen.dart';
import 'login_screen.dart';

class AddSaleScreen extends StatefulWidget {
  final Map<String, dynamic>? existingSale; // edit flow source (optional)
  final String? shopName; // pre-selected shop (optional)

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

  /// Single source of truth for picked day (midnight)
  late DateTime _selectedDay;

  /// Employees: whether Yesterday is allowed (disabled if yesterday sale already exists)
  bool _yesterdayEnabled = true;

  bool get _isEmployee {
    final app = context.read<AppDataProvider>();
    final me = app.loggedInUser ?? {};
    final role = (me['role'] ?? '').toString().toLowerCase();
    return role == 'employee';
  }

  DateTime get _today => _dayOnly(DateTime.now());
  DateTime get _yesterday => _today.subtract(const Duration(days: 1));

  @override
  void initState() {
    super.initState();
    _selectedDay = _dayOnly(
      _toDate(widget.existingSale?['createdAt']) ?? DateTime.now(),
    );
    _prefillIfEditingOnLoad();

    // After first frame, compute yesterday availability (if employee)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshEmployeeDayOptions();
    });
  }

  void _prefillIfEditingOnLoad() {
    if (widget.existingSale == null) return;
    final s = widget.existingSale!;
    _selectedShop = (s['shop'] ?? '').toString();
    _cashC.text = _numToText(s['cash']);
    _cardC.text = _numToText(s['card']);
    _otherC.text = _numToText(s['other']);
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

    // Active (non-deleted) shop names
    final allShops = app.shops
        .where((s) => (s['isDeleted'] ?? false) != true)
        .map((s) => (s['name'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList()
      ..sort();

    // Employee’s assigned shops
    final assigned = (me['assignedShops'] as List? ?? [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toSet();

    // Options per role
    final shopOptions =
        _isEmployee ? allShops.where((s) => assigned.contains(s)).toList() : allShops;

    // Decide selected shop
    final prevSelectedShop = _selectedShop;
    _selectedShop ??= (widget.existingSale?['shop']?.toString().isNotEmpty == true)
        ? widget.existingSale!['shop'].toString()
        : (widget.shopName?.isNotEmpty == true
            ? widget.shopName
            : (shopOptions.isNotEmpty ? shopOptions.first : null));

    // If the chosen shop changed, refresh employee options
    if (_isEmployee && (_selectedShop ?? '').isNotEmpty && _selectedShop != prevSelectedShop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshEmployeeDayOptions();
      });
    }

    final hasMultipleAssigned = _isEmployee && shopOptions.length > 1;
    final appBarTitleShop = _selectedShop ?? '—';
    final isEditingSource = widget.existingSale != null;

    final total = _parse(_cashC.text) + _parse(_cardC.text) + _parse(_otherC.text);

    final navigator = Navigator.of(context);

    return Scaffold(
      appBar: AppBar(
        // 🔙 Normal back button – sab roles ke liye
        leading: navigator.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => navigator.pop(),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isEditingSource ? 'Edit Daily Sale' : 'Add Daily Sale'),
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
        child: shopOptions.isEmpty && !isEditingSource
            ? const Center(child: Text('No shop available to add a sale.'))
            : Form(
                key: _formKey,
                child: ListView(
                  children: [
                    if (_isEmployee) _shopInfoCard(),
                    if (_isEmployee) const SizedBox(height: 12),

                    // Admin/Manager can change shop here; employee’s shop fixed
                    if (!_isEmployee)
                      DropdownButtonFormField<String>(
                        value: (_selectedShop != null &&
                                shopOptions.contains(_selectedShop))
                            ? _selectedShop
                            : (shopOptions.isNotEmpty ? shopOptions.first : null),
                        items: shopOptions
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) async {
                          setState(() => _selectedShop = v);
                          await _prefillFromServer(_selectedDay); // reload fields
                          await _refreshEmployeeDayOptions();
                        },
                        decoration: const InputDecoration(
                          labelText: 'Shop',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Select a shop' : null,
                      ),

                    if (!_isEmployee) const SizedBox(height: 16),

                    // ======== Date selection ========
                    if (_isEmployee)
                      _EmployeeDaySelector(
                        day: _selectedDay,
                        yesterdayEnabled: _yesterdayEnabled,
                        onSelectToday: () => _setDayAndPrefill(_today),
                        onSelectYesterday: () => _setDayAndPrefill(_yesterday),
                      )
                    else
                      _DateStepper(
                        day: _selectedDay,
                        canGoPrev: _canGoPrev(_selectedDay),
                        canGoNext: _canGoNext(_selectedDay),
                        onPrev: () async {
                          final d = _selectedDay.subtract(const Duration(days: 1));
                          await _setDayAndPrefill(d);
                        },
                        onNext: () async {
                          final d = _selectedDay.add(const Duration(days: 1));
                          await _setDayAndPrefill(d);
                        },
                        onPick: () async {
                          final limits = _pickerBounds();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDay,
                            firstDate: limits.$1,
                            lastDate: limits.$2,
                          );
                          if (picked != null) {
                            await _setDayAndPrefill(picked);
                          }
                        },
                      ),
                    const SizedBox(height: 16),
                    // =================================

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
                            icon: Icon(isEditingSource ? Icons.save : Icons.add),
                            label: Text(isEditingSource ? 'Update Sale' : 'Add Sale'),
                            onPressed:
                                () => isEditingSource ? _updateSale() : _submitSale(),
                          ),
                  ],
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

  // ---------- Role/date rules ----------

  // Employees: only today/yesterday; Admin/Manager: last ~4 months till today
  (DateTime, DateTime) _pickerBounds() {
    final today = _today;
    if (_isEmployee) {
      final first = _yesterday;
      return (first, today);
    }
    // admin/manager ~4 months back
    final fourMonthsAgo = DateTime(today.year, today.month - 4, today.day);
    return (_dayOnly(fourMonthsAgo), today);
  }

  bool _canGoPrev(DateTime d) {
    final (min, _) = _pickerBounds();
    return !_dayOnly(d).isAtSameMomentAs(min);
  }

  bool _canGoNext(DateTime d) {
    final (_, max) = _pickerBounds();
    return !_dayOnly(d).isAtSameMomentAs(max);
  }

  Future<void> _setDayAndPrefill(DateTime d) async {
    final dd = _dayOnly(d);
    setState(() => _selectedDay = dd);
    await _prefillFromServer(dd);
  }

  Future<void> _prefillFromServer(DateTime day) async {
    // if shop still not chosen, only update date
    if ((_selectedShop ?? '').isEmpty) return;

    try {
      final app = context.read<AppDataProvider>();
      final dayKey = app.dayKeyOf(day);
      final q = FirebaseFirestore.instance
          .collection('sales')
          .where('shop', isEqualTo: _selectedShop)
          .where('dayKey', isEqualTo: dayKey)
          .limit(1);

      final snap = await q.get();
      if (!mounted) return;

      if (snap.docs.isEmpty) {
        // Empty -> clear fields
        _cashC.text = '';
        _cardC.text = '';
        _otherC.text = '';
        setState(() {}); // refresh total
        return;
      }

      final m = snap.docs.first.data();
      _cashC.text = _numToText(m['cash']);
      _cardC.text = _numToText(m['card']);
      _otherC.text = _numToText(m['other']);
      setState(() {});
    } catch (_) {
      // silent; keep previous values
    }
  }

  // ---------- Employee Yesterday availability ----------

  Future<void> _refreshEmployeeDayOptions() async {
    if (!_isEmployee) return;
    if ((_selectedShop ?? '').isEmpty) {
      setState(() => _yesterdayEnabled = false);
      return;
    }
    final hasYesterday = await _hasSaleForDay(_selectedShop!, _yesterday);
    // Yesterday is enabled only if there is NO sale for yesterday.
    setState(() => _yesterdayEnabled = !hasYesterday);
  }

  Future<bool> _hasSaleForDay(String shop, DateTime day) async {
    try {
      final app = context.read<AppDataProvider>();
      final dayKey = app.dayKeyOf(day);
      final q = FirebaseFirestore.instance
          .collection('sales')
          .where('shop', isEqualTo: shop)
          .where('dayKey', isEqualTo: dayKey)
          .limit(1);
      final snap = await q.get();
      return snap.docs.isNotEmpty;
    } catch (_) {
      // On error, be conservative: consider yesterday as already used -> disable
      return true;
    }
  }

  // ---------- Submit / Update ----------

  double _parse(String s) => double.tryParse(s.trim()) ?? 0.0;

  String _numToText(dynamic n) {
    if (n == null) return '';
    final d = (n is num) ? n.toDouble() : double.tryParse('$n') ?? 0.0;
    return (d == 0) ? '' : d.toStringAsFixed(d % 1 == 0 ? 0 : 2);
  }

  DateTime? _toDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  (DateTime, DateTime) _dayBounds(DateTime date) {
    final start = _dayOnly(date);
    final end = start.add(const Duration(days: 1));
    return (start, end);
  }

  Future<void> _submitSale() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);

    if (!_formKey.currentState!.validate()) return;
    if ((_selectedShop ?? '').isEmpty) {
      _showSnack(messenger, theme, 'Select a shop');
      return;
    }

    // Employee-specific guardrails (UI already enforces, but we double-check)
    if (_isEmployee) {
      final d = _selectedDay;
      final isT = _dayOnly(d).isAtSameMomentAs(_today);
      final isY = _dayOnly(d).isAtSameMomentAs(_yesterday);
      if (!isT && !isY) {
        _showSnack(messenger, theme, 'Employees can only submit for Today or Yesterday');
        return;
      }
      if (isY) {
        final hasY = await _hasSaleForDay(_selectedShop!, _yesterday);
        if (hasY) {
          _showSnack(messenger, theme, 'Yesterday sale already submitted');
          return;
        }
      }
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
      final chosen = _selectedDay;
      final (from, _) = _dayBounds(chosen);
      final dayKey = app.dayKeyOf(chosen);

      // Unique per shop per day
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

      // store at fixed noon time for that day
      final createdAt = DateTime(chosen.year, chosen.month, chosen.day, 12, 0);

      final data = {
        'shop': _selectedShop,
        'employee': name,
        'cash': cash,
        'card': card,
        'other': other,
        'total': total,
        'createdAt': Timestamp.fromDate(createdAt),
        'dayKey': dayKey,
        'source': _isEmployee ? 'employee_manual' : 'admin_or_manager_manual',
      };

      await FirebaseFirestore.instance.collection('sales').add(data);

      await app.fetchSales();
      if (!mounted) return;
      _showSnack(messenger, theme, 'Sale added', ok: true);

      // After a successful submit, re-evaluate yesterday availability (in case day == today)
      if (_isEmployee) {
        await _refreshEmployeeDayOptions();
      }

      // Reset for next entry (stay on same day)
      _cashC.clear();
      _cardC.clear();
      _otherC.clear();
      setState(() {});
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

/// ======= Employees: Today / Yesterday selector (no date tab) =======
class _EmployeeDaySelector extends StatelessWidget {
  final DateTime day;
  final bool yesterdayEnabled;
  final VoidCallback onSelectToday;
  final VoidCallback onSelectYesterday;

  const _EmployeeDaySelector({
    required this.day,
    required this.yesterdayEnabled,
    required this.onSelectToday,
    required this.onSelectYesterday,
  });

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final today = _dayOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));

    final isToday = _isSameDay(day, today);
    final isYesterday = _isSameDay(day, yesterday);

    // When disabled, ChoiceChip greys out if onSelected is null; add slight opacity for “blur” feel.
    final yesterdayChip = Opacity(
      opacity: yesterdayEnabled ? 1.0 : 0.55,
      child: ChoiceChip(
        label: const Text('Yesterday'),
        selected: isYesterday,
        onSelected: yesterdayEnabled ? (_) => onSelectYesterday() : null,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text('Select Day', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ChoiceChip(
              label: const Text('Today'),
              selected: isToday,
              onSelected: (_) => onSelectToday(),
            ),
            const SizedBox(width: 10),
            yesterdayChip,
          ],
        ),
      ],
    );
  }
}

/// ======= Center Date Stepper widget (Admin/Manager) =======
class _DateStepper extends StatelessWidget {
  final DateTime day;
  final bool canGoPrev;
  final bool canGoNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPick;

  const _DateStepper({
    required this.day,
    required this.canGoPrev,
    required this.canGoNext,
    required this.onPrev,
    required this.onNext,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('dd MMM, yyyy').format(day);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Previous day',
          onPressed: canGoPrev ? onPrev : null,
          icon: const Icon(Icons.chevron_left),
        ),
        InkWell(
          onTap: onPick,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.10),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.green.withOpacity(0.65)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.event, size: 18, color: Colors.green),
                const SizedBox(width: 6),
                Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: 'Next day',
          onPressed: canGoNext ? onNext : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}
