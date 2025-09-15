import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

class OrdersSnapshotScreen extends StatefulWidget {
  const OrdersSnapshotScreen({super.key});

  @override
  State<OrdersSnapshotScreen> createState() => _OrdersSnapshotScreenState();
}

class _OrdersSnapshotScreenState extends State<OrdersSnapshotScreen> {
  DateTime _day = DateTime.now();
  String? _shop;
  bool _loading = false;
  List<Map<String, dynamic>> _orders = [];

  Future<void> _load() async {
    setState(() => _loading = true);
    final app = context.read<AppDataProvider>();
    final data = await app.fetchOrdersForDate(shopName: _shop, date: DateTime(_day.year, _day.month, _day.day));
    if (!mounted) return;
    setState(() { _orders = data; _loading = false; });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _fmt(num v) => NumberFormat.currency(locale: 'en_US', symbol: r'$').format(v);

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();
    final shops = <String>[
      'All',
      ...app.shops.map((e) => (e['name'] ?? e['shopName'] ?? '').toString()).where((e) => e.isNotEmpty).toSet(),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Orders (Daily Snapshot)')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                OutlinedButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context, initialDate: _day, firstDate: DateTime(2020), lastDate: DateTime(2100));
                    if (d!=null){ setState(()=>_day=d); _load(); }
                  },
                  child: Text(DateFormat('MMM d, yyyy').format(_day)),
                ),
                DropdownButton<String>(
                  value: _shop ?? 'All',
                  items: shops.map((s)=>DropdownMenuItem<String>(value:s,child:Text(s))).toList(),
                  onChanged: (v){ setState(()=>_shop=(v=='All')?null:v); _load(); },
                ),
              ],
            ),
          ),
          const Divider(height:0),
          if (_loading) const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_orders.isEmpty) const Expanded(child: Center(child: Text('No orders for selected day.')))
          else Expanded(
            child: ListView.separated(
              itemCount: _orders.length,
              separatorBuilder: (_, __) => const Divider(height:0),
              itemBuilder: (_, i){
                final o = _orders[i];
                final amt = (o['amount'] is num) ? o['amount'] as num : num.tryParse('${o['amount']}') ?? 0;
                return ListTile(
                  title: Text((o['wholesalerName'] ?? '').toString()),
                  subtitle: Text((o['shopName'] ?? '').toString()),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_fmt(amt), style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text((o['status'] ?? 'Pending').toString(), style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
