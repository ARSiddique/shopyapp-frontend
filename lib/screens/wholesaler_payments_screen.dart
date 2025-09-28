import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_data_provider.dart';

class WholesalerPaymentsScreen extends StatefulWidget {
  final String wholesalerName;
  const WholesalerPaymentsScreen({super.key, required this.wholesalerName});

  @override
  State<WholesalerPaymentsScreen> createState() => _WholesalerPaymentsScreenState();
}

class _WholesalerPaymentsScreenState extends State<WholesalerPaymentsScreen> {
  DateTime _anchor = DateTime.now();
  bool _loading = true;
  List<Map<String, dynamic>> _payments = [];

  @override
  void initState() { super.initState(); _load(); }

  (DateTime from, DateTime to) _monthRange() {
    final a = DateTime(_anchor.year, _anchor.month, 1);
    return (a, DateTime(a.year, a.month + 1, 1));
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final app = context.read<AppDataProvider>();
    final (from, to) = _monthRange();
    final rows = await app.fetchWholesalerPaymentsByName(
      from: from, to: to, wholesalerName: widget.wholesalerName,
    );
    rows.sort((a, b) => (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime));
    setState(() { _payments = rows; _loading = false; });
  }

  Future<void> _newPayment(String shop) async {
    final form = GlobalKey<FormState>();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String mode = 'Cash';
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Enter Payment ($shop)'),
        content: Form(
          key: form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: amountCtrl,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount'),
              validator: (v) => (double.tryParse(v ?? '') ?? 0) > 0 ? null : 'Enter amount',
            ),
            DropdownButtonFormField<String>(
              value: mode,
              items: const ['Cash','Bank','Card','UPI'].map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),
              onChanged: (v) => mode = v ?? 'Cash',
              decoration: const InputDecoration(labelText: 'Mode'),
            ),
            TextFormField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Note')),
          ]),
        ),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () async {
            if (!form.currentState!.validate()) return;
            await context.read<AppDataProvider>().recordWholesalerPayment(
              shopName: shop,
              wholesalerName: widget.wholesalerName,
              amount: double.parse(amountCtrl.text),
              note: noteCtrl.text,
              mode: mode,
            );
            if (!mounted) return;
            Navigator.pop(context);
            _load();
          }, child: const Text('Save')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();
    final theme = Theme.of(context);
    final shops = app.shops.map((e) => (e['name'] ?? '').toString()).toList();

    // group by shop → take last 4
    final Map<String, List<Map<String, dynamic>>> byShop = { for (final s in shops) s: [] };
    for (final p in _payments) {
      final s = (p['shopName'] ?? '').toString();
      if (s.isEmpty) continue;
      if (byShop[s]!.length < 4) byShop[s]!.add(p);
    }

    final (from, to) = _monthRange();
    final title = DateFormat('MMMM yyyy').format(from);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(
            children: [
              IconButton(onPressed: () { setState(()=> _anchor = DateTime(_anchor.year, _anchor.month-1, 1)); _load(); }, icon: const Icon(Icons.chevron_left)),
              Expanded(child: Center(child: Text(title, style: theme.textTheme.titleMedium))),
              IconButton(onPressed: () { setState(()=> _anchor = DateTime(_anchor.year, _anchor.month+1, 1)); _load(); }, icon: const Icon(Icons.chevron_right)),
            ],
          ),
        ),
        const Divider(height: 1),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: byShop.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                if (i == 0) {
                  return _header(theme);
                }
                final name = byShop.keys.elementAt(i - 1);
                final list = byShop[name]!;
                return _row(theme, name, list, onEnterPayment: () => _newPayment(name));
              },
            ),
          ),
      ],
    );
  }

  Widget _header(ThemeData theme) {
    return Row(children: [
      _cell(theme, 'Shop', flex: 28, bold: true),
      _cell(theme, 'Payment 1', flex: 18, bold: true),
      _cell(theme, 'Payment 2', flex: 18, bold: true),
      _cell(theme, 'Payment 3', flex: 18, bold: true),
      _cell(theme, 'Payment 4', flex: 18, bold: true),
      _cell(theme, 'Enter New', flex: 16, bold: true, align: TextAlign.center),
    ]);
  }

  Widget _row(ThemeData theme, String shop, List<Map<String, dynamic>> items,
      {required VoidCallback onEnterPayment}) {
    String fmt(Map<String, dynamic>? m) {
      if (m == null) return '-';
      final d = m['createdAt'] as DateTime?;
      final amt = (m['amount'] ?? 0).toStringAsFixed(0);
      return '${d!=null?DateFormat('MMMd').format(d):''}\n\$ $amt';
    }

    return Row(children: [
      _cell(theme, shop, flex: 28),
      _cell(theme, fmt(items.isNotEmpty ? items[0] : null), flex: 18),
      _cell(theme, fmt(items.length > 1 ? items[1] : null), flex: 18),
      _cell(theme, fmt(items.length > 2 ? items[2] : null), flex: 18),
      _cell(theme, fmt(items.length > 3 ? items[3] : null), flex: 18),
      _buttonCell(theme, onEnterPayment),
    ]);
  }

  Widget _cell(ThemeData theme, String text, {int flex = 20, bool bold = false, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: .25)),
          color: theme.colorScheme.surface,
        ),
        child: Text(text, textAlign: align, style: theme.textTheme.bodyMedium!.copyWith(
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        )),
      ),
    );
  }

  Widget _buttonCell(ThemeData theme, VoidCallback onTap) {
    return Expanded(
      flex: 16,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: .25)),
            color: theme.colorScheme.primaryContainer,
          ),
          child: const Center(child: Text('Add', style: TextStyle(fontWeight: FontWeight.w700))),
        ),
      ),
    );
  }
}
