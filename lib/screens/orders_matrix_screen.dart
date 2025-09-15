import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

class OrdersMatrixScreen extends StatefulWidget {
  const OrdersMatrixScreen({super.key});
  @override
  State<OrdersMatrixScreen> createState() => _OrdersMatrixScreenState();
}

class _OrdersMatrixScreenState extends State<OrdersMatrixScreen> {
  DateTime anchor = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders – Daily Matrix'),
        actions: [
          IconButton(onPressed: ()=>setState(()=>anchor = anchor.subtract(const Duration(days: 1))), icon: const Icon(Icons.chevron_left)),
          Center(child: Text(DateFormat('MMM dd, yyyy').format(anchor))),
          IconButton(onPressed: ()=>setState(()=>anchor = anchor.add(const Duration(days: 1))), icon: const Icon(Icons.chevron_right)),
        ],
      ),
      body: FutureBuilder(
        future: Future.wait([
          app.ordersMatrixForDate(date: anchor),
          app.fetchWholesalers(), // ensures list is fresh
        ]),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final matrix = (snap.data as List).first as Map<String, Map<String, Map<String, dynamic>>>;
          final cols = app.wholesalers.map((w)=> w['name'].toString()).toList();

          // header
          final header = Row(
            children: [
              _cell('Shop', bold: true, flex: 2),
              ...cols.map((c)=>_cell(c, bold: true)),
            ],
          );

          // rows
          final shopNames = matrix.keys.toList()..sort();
          final rows = shopNames.map((s){
            return Row(
              children: [
                _cell(s, bold: true, flex: 2),
                ...cols.map((wh){
                  final cell = matrix[s]?[wh];
                  if (cell == null) return _cell('');
                  final ok = cell['status'] != 'Pending' ? Icons.check_circle : Icons.check_circle_outline;
                  return _cellWidget(Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(ok, size: 18),
                      const SizedBox(width: 4),
                      Text((cell['amount'] as num).toStringAsFixed(0)),
                    ],
                  ));
                }),
              ],
            );
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(8),
            children: [header, const Divider(), ...rows],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final pulled = await app.pullAllShopOrdersForDate(date: anchor);
          if (!mounted) return;
          showModalBottomSheet(context: context, builder: (_) {
            final keys = pulled.keys.toList()..sort();
            return ListView(
              padding: const EdgeInsets.all(12),
              children: keys.map((wh){
                final items = pulled[wh]!;
                final kids = items.map((e)=> ListTile(
                  dense: true,
                  title: Text(e['shopName']),
                  trailing: Text('\$${(e['amount'] as num).toStringAsFixed(0)}'),
                  subtitle: Text(e['status']),
                ));
                return ExpansionTile(title: Text(wh), children: kids.toList());
              }).toList(),
            );
          });
        },
        label: const Text('Pull all shop orders'),
        icon: const Icon(Icons.view_list),
      ),
    );
  }

  Widget _cell(String text, {bool bold = false, int flex = 1}) =>
      Expanded(flex: flex, child: Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(6)),
        child: Text(text, textAlign: TextAlign.center, style: TextStyle(fontWeight: bold? FontWeight.w700 : FontWeight.w500)),
      ));

  Widget _cellWidget(Widget child, {int flex = 1}) =>
      Expanded(flex: flex, child: Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(6)),
        child: Center(child: child),
      ));
}
