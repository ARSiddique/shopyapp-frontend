import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_data_provider.dart';

class WholesalerDrilldownScreen extends StatefulWidget {
  final String? initialWholesaler;
  final String? initialShop; // optional filter
  const WholesalerDrilldownScreen({
    super.key,
    this.initialWholesaler,
    this.initialShop,
  });

  @override
  State<WholesalerDrilldownScreen> createState() =>
      _WholesalerDrilldownScreenState();
}

class _WholesalerDrilldownScreenState extends State<WholesalerDrilldownScreen> {
  final _df = DateFormat('MMM d, yyyy', 'en_US');

  String? _wholesaler;
  String _view = 'Monthly'; // Daily/Weekly/Monthly/Yearly
  DateTime _anchor = DateTime.now();
  String? _shopFilter;
  bool _loading = false;

  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _payments = [];

  @override
  void initState() {
    super.initState();
    _wholesaler = widget.initialWholesaler;
    _shopFilter = widget.initialShop;
    _load();
  }

  (DateTime from, DateTime to) _range() {
    final a = DateTime(_anchor.year, _anchor.month, _anchor.day);
    switch (_view) {
      case 'Daily':
        return (a, a.add(const Duration(days: 1)));
      case 'Weekly':
        final start = a.subtract(Duration(days: a.weekday - 1)); // Monday
        return (start, start.add(const Duration(days: 7)));
      case 'Yearly':
        return (DateTime(a.year, 1, 1), DateTime(a.year + 1, 1, 1));
      case 'Monthly':
      default:
        return (DateTime(a.year, a.month, 1), DateTime(a.year, a.month + 1, 1));
    }
  }

  Future<void> _load() async {
    if (_wholesaler == null || _wholesaler!.isEmpty) return;
    setState(() => _loading = true);
    final app = context.read<AppDataProvider>();
    final (from, to) = _range();
    final inv = await app.fetchWholesalerInvoicesByName(
      from: from,
      to: to,
      shopName: _shopFilter,
      wholesalerName: _wholesaler!,
    );
    final pay = await app.fetchWholesalerPaymentsByName(
      from: from,
      to: to,
      shopName: _shopFilter,
      wholesalerName: _wholesaler!,
    );
    if (!mounted) return;
    setState(() {
      _invoices = inv;
      _payments = pay;
      _loading = false;
    });
  }

  String _fmt(num v) => NumberFormat.currency(locale: 'en_US', symbol: r'$').format(v);

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();
    final (from, to) = _range();

    // group by shop: invoices + payments
    final Map<String, num> invByShop = {};
    final Map<String, num> payByShop = {};
    num gInv = 0, gPay = 0;

    for (final i in _invoices) {
      final shop = (i['shopName'] ?? i['shop'] ?? '').toString();
      final amt = (i['amount'] is num)
          ? (i['amount'] as num)
          : num.tryParse('${i['amount']}') ?? 0;
      invByShop[shop] = (invByShop[shop] ?? 0) + amt;
      gInv += amt;
    }
    for (final p in _payments) {
      final shop = (p['shopName'] ?? '').toString();
      final amt = (p['amount'] is num)
          ? (p['amount'] as num)
          : num.tryParse('${p['amount']}') ?? 0;
      payByShop[shop] = (payByShop[shop] ?? 0) + amt;
      gPay += amt;
    }
    final shops = {...invByShop.keys, ...payByShop.keys}.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wholesaler Details'),
        actions: [
          if (_wholesaler != null && _wholesaler!.isNotEmpty)
            IconButton(
              tooltip: 'Enter Payment',
              icon: const Icon(Icons.payments),
              onPressed: _enterPaymentDialog,
            ),
          if (_wholesaler != null && _wholesaler!.isNotEmpty)
            IconButton(
              tooltip: 'Update Balance',
              icon: const Icon(Icons.edit_note),
              onPressed: _updateBalanceDialog,
            ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _filters(app, from, to),
          const Divider(height: 0),
          if (_wholesaler == null)
            const Expanded(child: Center(child: Text('Select a wholesaler')))
          else if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView(
                children: [
                  // Summary cards
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        _metric('Invoices', _fmt(gInv)),
                        _metric('Paid', _fmt(gPay)),
                        _metric('Balance', _fmt(gInv - gPay), emphasize: true),
                      ],
                    ),
                  ),

                  // Per-shop rows
                  ...shops.map((s) {
                    final inv = invByShop[s] ?? 0;
                    final pay = payByShop[s] ?? 0;
                    final bal = inv - pay;
                    return ListTile(
                      title: Text(s.isEmpty ? '-' : s),
                      subtitle: Text('Invoices: ${_fmt(inv)}   |   Paid: ${_fmt(pay)}'),
                      trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_fmt(bal), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(width: 6),
        IconButton(
          tooltip: 'Add Payment',
          icon: const Icon(Icons.add_card),
          onPressed: () => _enterPaymentDialog(preselectShop: s.isEmpty ? null : s),
        ),
      ],
    ),
  );
}),

                  const SizedBox(height: 12),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _filters(AppDataProvider app, DateTime from, DateTime to) {
    final shopNames = <String>[
      'All',
      ...app.shops
          .map((s) => (s['name'] ?? s['shopName'] ?? '').toString())
          .where((e) => e.trim().isNotEmpty)
          .toSet(),
    ];

    final wholesalerNames = app.wholesalers
        .map((w) => (w['name'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toList();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // View
          DropdownButton<String>(
            value: _view,
            items: const ['Daily', 'Weekly', 'Monthly', 'Yearly']
                .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _view = v);
              _load();
            },
          ),

          // Anchor date
          OutlinedButton(
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _anchor,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (d != null) {
                setState(() => _anchor = d);
                _load();
              }
            },
            child: Text('${_df.format(from)} → ${_df.format(to.subtract(const Duration(days: 1)))}'),
          ),

          // Shop filter
          DropdownButton<String>(
            value: _shopFilter ?? 'All',
            items: shopNames
                .map((s) => DropdownMenuItem<String>(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) {
              setState(() => _shopFilter = (v == null || v == 'All') ? null : v);
              _load();
            },
          ),

          // Wholesaler
          DropdownButton<String>(
            value: _wholesaler,
            hint: const Text('Select wholesaler'),
            items: wholesalerNames
                .map((n) => DropdownMenuItem<String>(value: n, child: Text(n)))
                .toList(),
            onChanged: (v) {
              setState(() => _wholesaler = v);
              _load();
            },
          ),
        ],
      ),
    );
  }

  Widget _metric(String title, String value, {bool emphasize = false}) {
    final base = emphasize ? Colors.blue : Colors.grey;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: base.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: emphasize ? FontWeight.w800 : FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  // ---------- Dialogs ----------
Future<void> _enterPaymentDialog({String? preselectShop}) async {
  final app = context.read<AppDataProvider>();
  final shops = app.shops
      .where((s) => (s['isDeleted'] ?? false) != true)
      .map((s) => (s['name'] ?? '').toString())
      .where((n) => n.isNotEmpty)
      .toList()
    ..sort();

  String? shop = preselectShop ?? _shopFilter ?? (shops.isNotEmpty ? shops.first : null);
  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();

  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Enter Payment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: shop,
            items: shops.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
            onChanged: (v) => shop = v,
            decoration: const InputDecoration(labelText: 'Shop'),
          ),
          TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Amount'),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          ),
          TextField(
            controller: noteCtrl,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
            if (shop == null || amt <= 0 || _wholesaler == null) return;
            await app.recordWholesalerPayment(
              shopName: shop!,
              wholesalerName: _wholesaler!,
              amount: amt,
              note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
            );
            if (!mounted) return;
            Navigator.pop(context);
            _load();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Payment recorded for $shop')),
            );
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
  Future<void> _updateBalanceDialog() async {
    final app = context.read<AppDataProvider>();
    final shops = app.shops
        .where((s) => (s['isDeleted'] ?? false) != true)
        .map((s) => (s['name'] ?? '').toString())
        .where((n) => n.isNotEmpty)
        .toList()
      ..sort();

    String? shop = _shopFilter ?? (shops.isNotEmpty ? shops.first : null);
    final balCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    double currentBal = 0;

    if (shop != null && _wholesaler != null) {
      currentBal = await app.getWholesalerShopBalance(
        shopName: shop!,
        wholesalerName: _wholesaler!,
      );
    }

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Update Balance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: shop,
              items: shops.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
              onChanged: (v) async {
                shop = v;
                if (shop != null && _wholesaler != null) {
                  final b = await app.getWholesalerShopBalance(
                    shopName: shop!,
                    wholesalerName: _wholesaler!,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Current balance: $b')),
                    );
                  }
                }
              },
              decoration: const InputDecoration(labelText: 'Shop'),
            ),
            TextField(
              controller: balCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'New Balance',
                helperText: 'Current: $currentBal',
              ),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            ),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final newBal = double.tryParse(balCtrl.text.trim());
              if (shop == null || newBal == null || _wholesaler == null) return;
              await app.setWholesalerShopBalance(
                shopName: shop!,
                wholesalerName: _wholesaler!,
                newBalance: newBal,
                note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
              );
              if (!mounted) return;
              Navigator.pop(context);
              _load();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Balance updated')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
