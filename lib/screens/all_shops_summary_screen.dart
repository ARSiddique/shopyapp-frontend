// Unified All-Shops Summary (Sales implemented; other tabs scaffolded)
// Place at: lib/screens/all_shops_summary_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/app_data_provider.dart';
import '../providers/app_data_provider_extensions.dart';

class AllShopsSummaryScreen extends StatefulWidget {
  const AllShopsSummaryScreen({super.key});

  @override
  State<AllShopsSummaryScreen> createState() => _AllShopsSummaryScreenState();
}

class _AllShopsSummaryScreenState extends State<AllShopsSummaryScreen> {
  String selectedShop = 'All';
  String viewMode = 'Daily'; // Daily | Weekly | Monthly | Yearly
  DateTime anchorDate = DateTime.now();
  int tabIndex = 0; // 0: Sales, 1: Wholesalers, 2: Emp Exp, 3: Other Exp, 4: Orders
  bool _loading = false;

  List<Map<String, dynamic>> _sales = [];

  Future<void> _load() async {
    setState(() => _loading = true);
    final app = context.read<AppDataProvider>();

    DateTime from, to;
    if (viewMode == 'Weekly') {
      from = app.weekStart(anchorDate);
      to = app.weekEnd(anchorDate);
    } else if (viewMode == 'Monthly') {
      from = app.monthStart(anchorDate);
      to = app.monthEnd(anchorDate);
    } else if (viewMode == 'Yearly') {
      from = DateTime(anchorDate.year, 1, 1);
      to = DateTime(anchorDate.year + 1, 1, 1);
    } else {
      from = app.dayStart(anchorDate);
      to = app.dayEnd(anchorDate);
    }

    // SALES implemented; other tabs can be added similarly with provider helpers
    final sales = await app.fetchSalesBetween(from: from, to: to, shopName: selectedShop == 'All' ? null : selectedShop);

    setState(() {
      _sales = sales;
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();
    final shops = app.shops;
    final shopNames = <String>['All', ...shops
        .map((s) => (s['name'] ?? s['shopName'] ?? s['title'] ?? '').toString())
        .where((e) => e.trim().isNotEmpty)
        .toSet()
        .toList()];

    final df = DateFormat('MMM dd, yyyy');

    // Group sales by shop
    final Map<String, Map<String, num>> byShop = {};
    num grandTotal = 0;
    num grandCash = 0, grandCard = 0, grandOther = 0;

    for (final s in _sales) {
      final shop = (s['shopName'] ?? '').toString();
      final cash = (s['cash'] is num) ? s['cash'] as num : num.tryParse(s['cash'].toString()) ?? 0;
      final card = (s['card'] is num) ? s['card'] as num : num.tryParse(s['card'].toString()) ?? 0;
      final other = (s['other'] is num) ? s['other'] as num : num.tryParse(s['other'].toString()) ?? 0;
      final total = (s['total'] is num) ? s['total'] as num : num.tryParse(s['total'].toString()) ?? (cash + card + other);

      byShop.putIfAbsent(shop, () => {'cash': 0, 'card': 0, 'other': 0, 'total': 0});
      byShop[shop]!['cash'] = (byShop[shop]!['cash'] ?? 0) + cash;
      byShop[shop]!['card'] = (byShop[shop]!['card'] ?? 0) + card;
      byShop[shop]!['other'] = (byShop[shop]!['other'] ?? 0) + other;
      byShop[shop]!['total'] = (byShop[shop]!['total'] ?? 0) + total;

      grandCash += cash;
      grandCard += card;
      grandOther += other;
      grandTotal += total;
    }

    Widget _buildFilters() {
      return Padding(
        padding: const EdgeInsets.all(12.0),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DropdownButton<String>(
              value: viewMode,
              items: const [
                DropdownMenuItem(value: 'Daily', child: Text('Daily')),
                DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
                DropdownMenuItem(value: 'Yearly', child: Text('Yearly')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => viewMode = v);
                _load();
              },
            ),
            OutlinedButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: anchorDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  setState(() => anchorDate = picked);
                  _load();
                }
              },
              child: Text(df.format(anchorDate)),
            ),
            DropdownButton<String>(
              value: selectedShop,
              items: shopNames.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => selectedShop = v);
                _load();
              },
            ),
          ],
        ),
      );
    }

    Widget _buildTabs() {
      final tabs = const ['Sales', 'Wholesalers', 'Emp Exp', 'Other Exp', 'Orders'];
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(tabs.length, (i) {
              final active = tabIndex == i;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(tabs[i]),
                  selected: active,
                  onSelected: (_) {
                    setState(() => tabIndex = i);
                    _load(); // for now only sales will change anything
                  },
                ),
              );
            }),
          ),
        ),
      );
    }

    Widget _buildSalesTable() {
      if (_loading) return const Expanded(child: Center(child: CircularProgressIndicator()));
      if (byShop.isEmpty) return const Expanded(child: Center(child: Text('No sales found for selected range.')));

      final rows = byShop.entries.map((e) {
        final shop = e.key;
        final m = e.value;
        return DataRow(cells: [
          DataCell(Text(shop)),
          DataCell(Text((m['cash'] ?? 0).toString())),
          DataCell(Text((m['card'] ?? 0).toString())),
          DataCell(Text((m['other'] ?? 0).toString())),
          DataCell(Text((m['total'] ?? 0).toString())),
        ]);
      }).toList();

      // Totals row
      rows.add(DataRow(cells: [
        const DataCell(Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold))),
        DataCell(Text(grandCash.toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
        DataCell(Text(grandCard.toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
        DataCell(Text(grandOther.toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
        DataCell(Text(grandTotal.toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
      ]));

      return Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Shop')),
              DataColumn(label: Text('Cash')),
              DataColumn(label: Text('Card')),
              DataColumn(label: Text('Other')),
              DataColumn(label: Text('Total')),
            ],
            rows: rows,
          ),
        ),
      );
    }

    Widget _buildComingSoon(String title) {
      return Expanded(
        child: Center(
          child: Text('$title — Coming soon (wire with provider fetchers).'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('All Shops Summary')),
      body: Column(
        children: [
          _buildFilters(),
          const Divider(height: 0),
          _buildTabs(),
          const Divider(height: 0),
          if (tabIndex == 0) _buildSalesTable(),
          if (tabIndex == 1) _buildComingSoon('Wholesalers'),
          if (tabIndex == 2) _buildComingSoon('Employee Expenses'),
          if (tabIndex == 3) _buildComingSoon('Other Expenses'),
          if (tabIndex == 4) _buildComingSoon('Orders'),
        ],
      ),
    );
  }
}
