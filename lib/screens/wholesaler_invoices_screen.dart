// lib/screens/wholesaler_invoices_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

class WholesalerInvoicesScreen extends StatefulWidget {
  final String wholesalerName;
  const WholesalerInvoicesScreen({super.key, required this.wholesalerName});

  @override
  State<WholesalerInvoicesScreen> createState() => _WholesalerInvoicesScreenState();
}

class _WholesalerInvoicesScreenState extends State<WholesalerInvoicesScreen> {
  String _view = 'Monthly';
  int _periodShift = 0;
  final DateTime _anchor = DateTime.now();
  bool _loading = false;

  DateTime get _shiftedAnchor {
    final d = DateTime(_anchor.year, _anchor.month, _anchor.day);
    switch (_view) {
      case 'Daily':  return d.add(Duration(days: _periodShift));
      case 'Weekly': return d.add(Duration(days: 7 * _periodShift));
      case 'Yearly': return DateTime(d.year + _periodShift, d.month, d.day);
      default:       return DateTime(d.year, d.month + _periodShift, 1);
    }
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final app = context.read<AppDataProvider>();
      final r = rangeForView(_view, _shiftedAnchor);
      await Future.wait([
        app.fetchWholesalerInvoicesByName(
          from: r.from, to: r.to, shopName: null, wholesalerName: widget.wholesalerName),
        app.fetchWholesalerPaymentsByName(
          from: r.from, to: r.to, shopName: null, wholesalerName: widget.wholesalerName),
      ]);
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  void initState() { super.initState(); _refresh(); }

  String _rangeTitle() {
    final r = rangeForView(_view, _shiftedAnchor);
    final dfM = DateFormat('MMMM yyyy'), dfD = DateFormat('MMM d, yyyy');
    switch (_view) {
      case 'Daily':  return dfD.format(r.from);
      case 'Weekly': return '${dfD.format(r.from)} – ${dfD.format(r.to.subtract(const Duration(days:1)))}';
      case 'Yearly': return '${r.from.year}';
      default:       return dfM.format(r.from);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();
    final r = rangeForView(_view, _shiftedAnchor);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.wholesalerName),
          bottom: const TabBar(tabs: [Tab(text: 'Invoices'), Tab(text: 'Payments'), Tab(text: 'Balance')]),
          actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh)],
        ),

        body: Column(
          children: [
            // 🔹 Header row wrapped in Material (fixes DropdownButton error)
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _view,
                        items: const ['Daily','Weekly','Monthly','Yearly']
                          .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                        onChanged: (v) { if (v!=null) { setState((){ _view=v; _periodShift=0;}); _refresh(); } },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(icon: const Icon(Icons.chevron_left),  onPressed: () { setState(()=>_periodShift--); _refresh(); }),
                    Expanded(
                      child: Center(child: Text(_rangeTitle(), style: const TextStyle(fontWeight: FontWeight.w600))),
                    ),
                    IconButton(icon: const Icon(Icons.chevron_right), onPressed: () { setState(()=>_periodShift++); _refresh(); }),
                    const SizedBox(width: 8),
                    FilledButton.icon(onPressed: (){}, icon: const Icon(Icons.payments), label: const Text('Pay')),
                  ],
                ),
              ),
            ),
            if (_loading) const LinearProgressIndicator(minHeight: 2),

            Expanded(
              child: TabBarView(
                children: [
                  // Invoices
                  FutureBuilder(
                    future: app.fetchWholesalerInvoicesByName(
                      from: r.from, to: r.to, shopName: null, wholesalerName: widget.wholesalerName),
                    builder: (_, snap) {
                      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                      final list = snap.data as List<Map<String, dynamic>>;
                      if (list.isEmpty) return const Center(child: Text('No invoices'));
                      return ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final m = list[i];
                          final dt = (m['createdAt'] as DateTime?) ?? DateTime.now();
                          final amt = (m['amount'] ?? 0.0) as double;
                          return ListTile(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Theme.of(context).dividerColor)),
                            title: Text((m['shopName'] ?? '').toString()),
                            subtitle: Text(DateFormat('MMM d, yyyy – h:mm a').format(dt)),
                            trailing: Text('\$${amt.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          );
                        },
                      );
                    },
                  ),

                  // Payments
                  FutureBuilder(
                    future: app.fetchWholesalerPaymentsByName(
                      from: r.from, to: r.to, shopName: null, wholesalerName: widget.wholesalerName),
                    builder: (_, snap) {
                      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                      final list = snap.data as List<Map<String, dynamic>>;
                      if (list.isEmpty) return const Center(child: Text('No payments'));
                      return ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final m = list[i];
                          final dt = (m['createdAt'] as DateTime?) ?? DateTime.now();
                          final amt = (m['amount'] ?? 0.0) as double;
                          final mode = (m['mode'] ?? 'Cash').toString();
                          return ListTile(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Theme.of(context).dividerColor)),
                            title: Text('${m['shopName'] ?? ''} · $mode'),
                            subtitle: Text(DateFormat('MMM d, yyyy – h:mm a').format(dt)),
                            trailing: Text('-\$${amt.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          );
                        },
                      );
                    },
                  ),

                  // Balance
                  FutureBuilder(
                    future: Future.wait([
                      app.fetchWholesalerInvoicesByName(from: r.from, to: r.to, shopName: null, wholesalerName: widget.wholesalerName),
                      app.fetchWholesalerPaymentsByName(from: r.from, to: r.to, shopName: null, wholesalerName: widget.wholesalerName),
                    ]),
                    builder: (_, snap) {
                      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                      final inv = (snap.data![0]).fold<double>(0, (s,m)=>s+(m['amount'] as double));
                      final pay = (snap.data![1]).fold<double>(0, (s,m)=>s+(m['amount'] as double));
                      final bal = inv - pay;
                      return Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text('Invoices:  \$${inv.toStringAsFixed(2)}'),
                          const SizedBox(height: 6),
                          Text('Payments: -\$${pay.toStringAsFixed(2)}'),
                          const SizedBox(height: 12),
                          Text('Balance:  \$${bal.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        ]),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
