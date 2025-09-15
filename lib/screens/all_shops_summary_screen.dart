import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../providers/app_data_provider.dart';
import 'wholesaler_drilldown_screen.dart';

// Global formatter
final NumberFormat _usd = NumberFormat.currency(locale: 'en_US', symbol: r'$');

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

  // Data caches
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _empExpenses = [];
  List<Map<String, dynamic>> _otherExpenses = [];
  List<Map<String, dynamic>> _ordersDay = [];

  // ---- Helpers ----
  DateFormat get _df => DateFormat('MMM dd, yyyy', 'en_US');
  String _fmtMoney(num v) => _usd.format(v);

  (DateTime from, DateTime to) _rangeForView() {
    final a = DateTime(anchorDate.year, anchorDate.month, anchorDate.day);
    switch (viewMode) {
      case 'Weekly':
        final start = a.subtract(Duration(days: a.weekday - 1)); // Monday
        return (start, start.add(const Duration(days: 7)));
      case 'Monthly':
        final start = DateTime(a.year, a.month, 1);
        return (start, DateTime(a.year, a.month + 1, 1));
      case 'Yearly':
        final start = DateTime(a.year, 1, 1);
        return (start, DateTime(a.year + 1, 1, 1));
      case 'Daily':
      default:
        final start = DateTime(a.year, a.month, a.day);
        return (start, start.add(const Duration(days: 1)));
    }
  }

  void _shiftAnchor(int dir) {
    setState(() {
      if (viewMode == 'Daily') {
        anchorDate = anchorDate.add(Duration(days: dir));
      } else if (viewMode == 'Weekly') {
        anchorDate = anchorDate.add(Duration(days: 7 * dir));
      } else if (viewMode == 'Monthly') {
        anchorDate =
            DateTime(anchorDate.year, anchorDate.month + dir, anchorDate.day);
      } else {
        anchorDate =
            DateTime(anchorDate.year + dir, anchorDate.month, anchorDate.day);
      }
    });
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final app = context.read<AppDataProvider>();
    final (from, to) = _rangeForView();
    final shopFilter = selectedShop == 'All' ? null : selectedShop;

    final sales = await app.fetchSalesBetween(
        from: from, to: to, shopName: shopFilter);
    final invoices = await app.fetchWholesalerInvoices(
        from: from, to: to, shopName: shopFilter);
    final pays = await app.fetchWholesalerPaymentsBetween(
        from: from, to: to, shopName: shopFilter);
    final empExp = await app.fetchEmployeeExpenses(
        from: from, to: to, shopName: shopFilter);
    final othExp = await app.fetchOtherExpenses(
        from: from, to: to, shopName: shopFilter);

    List<Map<String, dynamic>> ordersDay = [];
    if (viewMode == 'Daily') {
      ordersDay = await app.fetchOrdersForDate(shopName: shopFilter, date: from);
    }

    if (!mounted) return;
    setState(() {
      _sales = sales;
      _invoices = invoices;
      _payments = pays;
      _empExpenses = empExp;
      _otherExpenses = othExp;
      _ordersDay = ordersDay;
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  // -------- EXPORT (copy CSV to clipboard) --------
  void _exportCurrentTabCSV() {
    String csv = '';
    switch (tabIndex) {
      case 0:
        csv = _csvSales();
        break;
      case 1:
        csv = _csvWholesalers();
        break;
      case 2:
        csv = _csvSimpleSum(_empExpenses, ['shopName', 'amount'],
            header: 'Shop,EmployeeExpense');
        break;
      case 3:
        csv = _csvSimpleSum(_otherExpenses, ['shopName', 'amount'],
            header: 'Shop,OtherExpense');
        break;
      case 4:
        csv = _csvOrders();
        break;
    }
    Clipboard.setData(ClipboardData(text: csv));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV copied to clipboard')),
    );
  }

  String _csvSales() {
    final Map<String, Map<String, num>> byShop = {};
    for (final s in _sales) {
      final shop = (s['shop'] ?? s['shopName'] ?? '').toString();
      final cash = (s['cash'] is num)
          ? s['cash'] as num
          : num.tryParse('${s['cash']}') ?? 0;
      final card = (s['card'] is num)
          ? s['card'] as num
          : num.tryParse('${s['card']}') ?? 0;
      final other = (s['other'] is num)
          ? s['other'] as num
          : num.tryParse('${s['other']}') ?? 0;
      final total = (s['total'] is num)
          ? s['total'] as num
          : num.tryParse('${s['total']}') ?? (cash + card + other);

      byShop.putIfAbsent(shop,
          () => {'cash': 0, 'card': 0, 'other': 0, 'total': 0});
      byShop[shop]!['cash'] = (byShop[shop]!['cash'] ?? 0) + cash;
      byShop[shop]!['card'] = (byShop[shop]!['card'] ?? 0) + card;
      byShop[shop]!['other'] = (byShop[shop]!['other'] ?? 0) + other;
      byShop[shop]!['total'] = (byShop[shop]!['total'] ?? 0) + total;
    }
    final buf = StringBuffer('Shop,Cash,Card,Other,Total\n');
    byShop.forEach((k, m) {
      buf.writeln(
          '$k,${m['cash'] ?? 0},${m['card'] ?? 0},${m['other'] ?? 0},${m['total'] ?? 0}');
    });
    return buf.toString();
  }

  String _csvWholesalers() {
    final Map<String, num> invByShop = {};
    final Map<String, num> payByShop = {};
    for (final inv in _invoices) {
      final shop = (inv['shopName'] ?? inv['shop'] ?? '').toString();
      final amt = (inv['amount'] ?? 0) is num
          ? inv['amount'] as num
          : num.tryParse('${inv['amount']}') ?? 0;
      invByShop[shop] = (invByShop[shop] ?? 0) + amt;
    }
    for (final p in _payments) {
      final shop = (p['shopName'] ?? '').toString();
      final amt = (p['amount'] ?? 0) is num
          ? p['amount'] as num
          : num.tryParse('${p['amount']}') ?? 0;
      payByShop[shop] = (payByShop[shop] ?? 0) + amt;
    }
    final all = {...invByShop.keys, ...payByShop.keys}.toList()..sort();
    final buf = StringBuffer('Shop,Invoices,Paid,Balance\n');
    for (final s in all) {
      final inv = invByShop[s] ?? 0;
      final pay = payByShop[s] ?? 0;
      final bal = inv - pay;
      buf.writeln('$s,$inv,$pay,$bal');
    }
    return buf.toString();
  }

  String _csvSimpleSum(List<Map<String, dynamic>> list, List<String> fields,
      {required String header}) {
    final Map<String, num> sumBy = {};
    for (final e in list) {
      final key = (e[fields[0]] ?? '').toString();
      final amt = (e[fields[1]] ?? 0) is num
          ? e[fields[1]] as num
          : num.tryParse('${e[fields[1]]}') ?? 0;
      sumBy[key] = (sumBy[key] ?? 0) + amt;
    }
    final buf = StringBuffer('$header\n');
    sumBy.forEach((k, v) => buf.writeln('$k,$v'));
    return buf.toString();
  }

  String _csvOrders() {
    final buf = StringBuffer('Shop,Wholesaler,Amount,Status\n');
    for (final o in _ordersDay) {
      final amount = (o['amount'] ?? 0) is num
          ? o['amount'] as num
          : num.tryParse('${o['amount']}') ?? 0;
      buf.writeln(
          '${o['shopName'] ?? ''},${o['wholesalerName'] ?? ''},$amount,${o['status'] ?? 'Pending'}');
    }
    return buf.toString();
  }

  // ---------- QUICK ADD ----------
  void _openQuickAdd() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _QuickAddSheet(
        currentShop: selectedShop == 'All' ? null : selectedShop,
        onDone: () {
          Navigator.pop(context);
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();

    // Role-guard
    if (!app.isAdmin && !app.isManager) {
      return Scaffold(
        appBar: AppBar(title: const Text('All Shops Summary')),
        body: const Center(
          child: Text('Only Admin/Manager can view All Shops Summary.'),
        ),
      );
    }

    final shops = app.shops;
    final shopNames = <String>[
      'All',
      ...shops
          .map((s) =>
              (s['name'] ?? s['shopName'] ?? s['title'] ?? '').toString())
          .where((e) => e.trim().isNotEmpty)
          .toSet(),
    ];

    final (from, to) = _rangeForView();

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Shops Summary'),
        actions: [
          IconButton(
            tooltip: 'Previous',
            onPressed: _loading ? null : () => _shiftAnchor(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          Center(
              child: Text(
                  '${_df.format(from)}  →  ${_df.format(to.subtract(const Duration(days: 1)))}')),
          IconButton(
            tooltip: 'Next',
            onPressed: _loading ? null : () => _shiftAnchor(1),
            icon: const Icon(Icons.chevron_right),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Export (CSV to clipboard)',
            onPressed: _exportCurrentTabCSV,
            icon: const Icon(Icons.file_download),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(shopNames.toList()),
          const Divider(height: 0),
          _buildTabs(),
          const Divider(height: 0),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6),
                child: _buildActiveTab(),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openQuickAdd,
        label: const Text('Quick Add'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  // ---- UI Pieces ----
  Widget _buildFilters(List<String> shopNames) {
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
            child: Text(_df.format(anchorDate)),
          ),
          DropdownButton<String>(
            value: selectedShop,
            items: shopNames
                .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                .toList(),
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
                onSelected: (_) => setState(() => tabIndex = i),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildActiveTab() {
    switch (tabIndex) {
      case 0:
        return _buildSales();
      case 1:
        return _buildWholesalers();
      case 2:
        return _buildEmployeeExpenses();
      case 3:
        return _buildOtherExpenses();
      case 4:
        return _buildOrders();
      default:
        return const SizedBox.shrink();
    }
  }

  // ---- Tab: Sales ----
  Widget _buildSales() {
    final Map<String, Map<String, num>> byShop = {};
    num gCash = 0, gCard = 0, gOther = 0, gTotal = 0;

    for (final s in _sales) {
      final shop = (s['shop'] ?? s['shopName'] ?? '').toString();
      final cash = (s['cash'] is num)
          ? s['cash'] as num
          : num.tryParse('${s['cash']}') ?? 0;
      final card = (s['card'] is num)
          ? s['card'] as num
          : num.tryParse('${s['card']}') ?? 0;
      final other = (s['other'] is num)
          ? s['other'] as num
          : num.tryParse('${s['other']}') ?? 0;
      final total = (s['total'] is num)
          ? s['total'] as num
          : num.tryParse('${s['total']}') ?? (cash + card + other);

      byShop.putIfAbsent(shop,
          () => {'cash': 0, 'card': 0, 'other': 0, 'total': 0});
      byShop[shop]!['cash'] = (byShop[shop]!['cash'] ?? 0) + cash;
      byShop[shop]!['card'] = (byShop[shop]!['card'] ?? 0) + card;
      byShop[shop]!['other'] = (byShop[shop]!['other'] ?? 0) + other;
      byShop[shop]!['total'] = (byShop[shop]!['total'] ?? 0) + total;

      gCash += cash;
      gCard += card;
      gOther += other;
      gTotal += total;
    }

    final cards = _totalsRow(cards: [
      _metricCard('Cash', _fmtMoney(gCash), onTap: () => setState(() => tabIndex = 0)),
      _metricCard('Card', _fmtMoney(gCard), onTap: () => setState(() => tabIndex = 0)),
      _metricCard('Other', _fmtMoney(gOther), onTap: () => setState(() => tabIndex = 0)),
      _metricCard('POS Cash', _fmtMoney(gCash + gCard + gOther), onTap: () => setState(() => tabIndex = 0)),
      _metricCard('Sales Total', _fmtMoney(gTotal), emphasize: true, onTap: () => setState(() => tabIndex = 0)),
    ]);

    final rows = byShop.entries.map((e) {
      final m = e.value;
      return DataRow(cells: [
        DataCell(Text(e.key.isEmpty ? '-' : e.key)),
        DataCell(Text(_fmtMoney(m['cash'] ?? 0))),
        DataCell(Text(_fmtMoney(m['card'] ?? 0))),
        DataCell(Text(_fmtMoney(m['other'] ?? 0))),
        DataCell(Text(_fmtMoney(m['total'] ?? 0))),
      ]);
    }).toList();

    rows.add(DataRow(cells: [
      const DataCell(
          Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold))),
      DataCell(Text(_fmtMoney(gCash),
          style: const TextStyle(fontWeight: FontWeight.bold))),
      DataCell(Text(_fmtMoney(gCard),
          style: const TextStyle(fontWeight: FontWeight.bold))),
      DataCell(Text(_fmtMoney(gOther),
          style: const TextStyle(fontWeight: FontWeight.bold))),
      DataCell(Text(_fmtMoney(gTotal),
          style: const TextStyle(fontWeight: FontWeight.bold))),
    ]));

    final table = _dataTable(
      columns: const ['Shop', 'Cash', 'Card', 'Other', 'Total'],
      rows: rows,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [cards, const SizedBox(height: 8), Expanded(child: table)],
    );
  }

  // ---- Tab: Wholesalers ----
  Widget _buildWholesalers() {
    final Map<String, num> invByShop = {};
    final Map<String, num> payByShop = {};
    num gInv = 0, gPay = 0;

    for (final inv in _invoices) {
      final shop = (inv['shopName'] ?? inv['shop'] ?? '').toString();
      final amt = (inv['amount'] ?? 0) is num
          ? inv['amount'] as num
          : num.tryParse('${inv['amount']}') ?? 0;
      invByShop[shop] = (invByShop[shop] ?? 0) + amt;
      gInv += amt;
    }
    for (final p in _payments) {
      final shop = (p['shopName'] ?? '').toString();
      final amt = (p['amount'] ?? 0) is num
          ? p['amount'] as num
          : num.tryParse('${p['amount']}') ?? 0;
      payByShop[shop] = (payByShop[shop] ?? 0) + amt;
      gPay += amt;
    }

    final allShops = {...invByShop.keys, ...payByShop.keys}.toList()..sort();

    final rows = allShops.map((shop) {
      final inv = invByShop[shop] ?? 0;
      final pay = payByShop[shop] ?? 0;
      final bal = inv - pay;

      void _openDrilldown() {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WholesalerDrilldownScreen(
              initialShop: shop.isEmpty ? null : shop,
            ),
          ),
        );
      }

      return DataRow(
        onSelectChanged: (sel) {
          if (sel == true) _openDrilldown();
        },
        cells: [
          DataCell(Text(shop.isEmpty ? '-' : shop)),
          DataCell(Text(_fmtMoney(inv))),
          DataCell(Text(_fmtMoney(pay))),
          DataCell(Text(_fmtMoney(bal))),
          DataCell(
            IconButton(
              tooltip: 'Open Drilldown',
              icon: const Icon(Icons.open_in_new),
              onPressed: _openDrilldown,
            ),
          ),
        ],
      );
    }).toList();

    rows.add(DataRow(cells: [
      const DataCell(
          Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold))),
      DataCell(Text(_fmtMoney(gInv),
          style: const TextStyle(fontWeight: FontWeight.bold))),
      DataCell(Text(_fmtMoney(gPay),
          style: const TextStyle(fontWeight: FontWeight.bold))),
      DataCell(Text(_fmtMoney(gInv - gPay),
          style: const TextStyle(fontWeight: FontWeight.bold))),
      const DataCell(SizedBox.shrink()),
    ]));

    final cards = _totalsRow(cards: [
      _metricCard('Invoices', _fmtMoney(gInv),
          onTap: () => setState(() => tabIndex = 1)),
      _metricCard('Paid', _fmtMoney(gPay),
          onTap: () => setState(() => tabIndex = 1)),
      _metricCard('Balance', _fmtMoney(gInv - gPay),
          emphasize: true, onTap: () => setState(() => tabIndex = 1)),
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        cards,
        const SizedBox(height: 8),
        Expanded(
          child: _dataTable(
            columns: const ['Shop', 'Invoices', 'Paid', 'Balance', 'Action'],
            rows: rows,
          ),
        ),
      ],
    );
  }

  // ---- Tab: Employee Expenses ----
  Widget _buildEmployeeExpenses() {
    final Map<String, num> sumByShop = {};
    num grand = 0;
    for (final e in _empExpenses) {
      final shop = (e['shopName'] ?? '').toString();
      final amt = (e['amount'] ?? 0) is num
          ? e['amount'] as num
          : num.tryParse('${e['amount']}') ?? 0;
      sumByShop[shop] = (sumByShop[shop] ?? 0) + amt;
      grand += amt;
    }

    final rows = sumByShop.entries.map((e) {
      return DataRow(cells: [
        DataCell(Text(e.key.isEmpty ? '-' : e.key)),
        DataCell(Text(_fmtMoney(e.value))),
      ]);
    }).toList();

    rows.add(DataRow(cells: [
      const DataCell(
          Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold))),
      DataCell(Text(_fmtMoney(grand),
          style: const TextStyle(fontWeight: FontWeight.bold))),
    ]));

    final cards = _totalsRow(cards: [
      _metricCard('Employee Expense', _fmtMoney(grand),
          emphasize: true, onTap: () => setState(() => tabIndex = 2)),
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        cards,
        const SizedBox(height: 8),
        Expanded(
          child: _dataTable(
            columns: const ['Shop', 'Amount'],
            rows: rows,
          ),
        ),
      ],
    );
  }

  // ---- Tab: Other Expenses ----
  Widget _buildOtherExpenses() {
    final Map<String, num> sumByShop = {};
    num grand = 0;
    for (final e in _otherExpenses) {
      final shop = (e['shopName'] ?? '').toString();
      final amt = (e['amount'] ?? 0) is num
          ? e['amount'] as num
          : num.tryParse('${e['amount']}') ?? 0;
      sumByShop[shop] = (sumByShop[shop] ?? 0) + amt;
      grand += amt;
    }

    final rows = sumByShop.entries.map((e) {
      return DataRow(cells: [
        DataCell(Text(e.key.isEmpty ? '-' : e.key)),
        DataCell(Text(_fmtMoney(e.value))),
      ]);
    }).toList();

    rows.add(DataRow(cells: [
      const DataCell(
          Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold))),
      DataCell(Text(_fmtMoney(grand),
          style: const TextStyle(fontWeight: FontWeight.bold))),
    ]));

    final cards = _totalsRow(cards: [
      _metricCard('Other Expense', _fmtMoney(grand),
          emphasize: true, onTap: () => setState(() => tabIndex = 3)),
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        cards,
        const SizedBox(height: 8),
        Expanded(
          child: _dataTable(
            columns: const ['Shop', 'Amount'],
            rows: rows,
          ),
        ),
      ],
    );
  }

  // ---- Tab: Orders (Daily snapshot) ----
  Widget _buildOrders() {
    if (viewMode != 'Daily') {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Orders snapshot is available in Daily view.'),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                setState(() => viewMode = 'Daily');
                _load();
              },
              child: const Text('Switch to Daily'),
            ),
          ],
        ),
      );
    }

    if (_ordersDay.isEmpty) {
      return const Center(child: Text('No orders for the selected day.'));
    }

    final rows = _ordersDay.map((o) {
      final amount = (o['amount'] ?? 0) is num
          ? o['amount'] as num
          : num.tryParse('${o['amount']}') ?? 0;
      return DataRow(cells: [
        DataCell(Text((o['shopName'] ?? '').toString())),
        DataCell(Text((o['wholesalerName'] ?? '').toString())),
        DataCell(Text(_fmtMoney(amount))),
        DataCell(Text((o['status'] ?? 'Pending').toString())),
      ]);
    }).toList();

    return _dataTable(
      columns: const ['Shop', 'Wholesaler', 'Amount', 'Status'],
      rows: rows,
    );
  }

  // ---- Reusable UI bits ----
  Widget _dataTable(
      {required List<String> columns, required List<DataRow> rows}) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: columns.map((c) => DataColumn(label: Text(c))).toList(),
        rows: rows,
      ),
    );
  }

  Widget _metricCard(String title, String value,
      {bool emphasize = false, VoidCallback? onTap}) {
    final base = emphasize ? Colors.blue : Colors.grey;
    final card = Container(
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
          Text(title,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: emphasize ? FontWeight.w800 : FontWeight.w700)),
        ],
      ),
    );
    return Expanded(
      child: onTap == null
          ? card
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: card,
            ),
    );
  }

  Widget _totalsRow({required List<Widget> cards}) {
    return Row(children: cards);
  }
}

// ---------------- QUICK ADD SHEET ----------------

class _QuickAddSheet extends StatefulWidget {
  final String? currentShop;
  final VoidCallback onDone;
  const _QuickAddSheet({required this.currentShop, required this.onDone});

  @override
  State<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<_QuickAddSheet> {
  String _mode = 'invoice'; // invoice | payment | other_exp | emp_exp

  // common
  String? _shopName;
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  // invoice/payment
  String? _wholesalerName;

  // emp exp
  String _empType = 'salary';
  String? _employeeName;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _shopName = widget.currentShop; // may be null (All)
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();
    final shops = [
      ...app.shops
          .map((s) => (s['name'] ?? s['shopName'] ?? '').toString())
          .where((e) => e.isNotEmpty),
    ];
    final wholesalers = app.wholesalers
        .map((w) => (w['name'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toList();
    final employees = app.employees
        .map((e) => (e['name'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // mode selector
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                    label: const Text('Invoice'),
                    selected: _mode == 'invoice',
                    onSelected: (_) => setState(() => _mode = 'invoice')),
                ChoiceChip(
                    label: const Text('Payment'),
                    selected: _mode == 'payment',
                    onSelected: (_) => setState(() => _mode = 'payment')),
                ChoiceChip(
                    label: const Text('Other Expense'),
                    selected: _mode == 'other_exp',
                    onSelected: (_) => setState(() => _mode = 'other_exp')),
                ChoiceChip(
                    label: const Text('Employee Expense'),
                    selected: _mode == 'emp_exp',
                    onSelected: (_) => setState(() => _mode = 'emp_exp')),
              ],
            ),
            const SizedBox(height: 12),

            // shop
            DropdownButtonFormField<String>(
              value: _shopName?.isNotEmpty == true ? _shopName : null,
              items: shops
                  .map((s) => DropdownMenuItem<String>(value: s, child: Text(s)))
                  .toList(),
              decoration: const InputDecoration(labelText: 'Shop'),
              onChanged: (v) => setState(() => _shopName = v),
            ),

            const SizedBox(height: 8),

            if (_mode == 'invoice' || _mode == 'payment') ...[
              DropdownButtonFormField<String>(
                value: _wholesalerName,
                items: wholesalers
                    .map((w) =>
                        DropdownMenuItem<String>(value: w, child: Text(w)))
                    .toList(),
                decoration: const InputDecoration(labelText: 'Wholesaler'),
                onChanged: (v) => setState(() => _wholesalerName = v),
              ),
              const SizedBox(height: 8),
            ],

            if (_mode == 'emp_exp') ...[
              DropdownButtonFormField<String>(
                value: _employeeName,
                items: employees
                    .map((e) =>
                        DropdownMenuItem<String>(value: e, child: Text(e)))
                    .toList(),
                decoration:
                    const InputDecoration(labelText: 'Employee (optional)'),
                onChanged: (v) => setState(() => _employeeName = v),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _empType,
                items: const ['salary', 'advance', 'paid']
                    .map((t) =>
                        DropdownMenuItem<String>(value: t, child: Text(t)))
                    .toList(),
                decoration: const InputDecoration(labelText: 'Type'),
                onChanged: (v) => setState(() => _empType = v ?? 'salary'),
              ),
              const SizedBox(height: 8),
            ],

            TextFormField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving
                        ? null
                        : () async {
                            final shop = _shopName ?? '';
                            final amt =
                                double.tryParse(_amountCtrl.text.trim()) ?? 0;
                            if (shop.isEmpty || amt <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Please select shop and valid amount')),
                              );
                              return;
                            }
                            setState(() => _saving = true);
                            try {
                              final app = context.read<AppDataProvider>();
                              if (_mode == 'invoice') {
                                if ((_wholesalerName ?? '').isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Select wholesaler')),
                                  );
                                } else {
                                  final err =
                                      await app.placeOrderUniquePerDay(
                                    shopName: shop,
                                    wholesalerName: _wholesalerName!,
                                    amount: amt,
                                    note: _noteCtrl.text.trim().isEmpty
                                        ? null
                                        : _noteCtrl.text.trim(),
                                  );
                                  if (err != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(err)));
                                  } else {
                                    widget.onDone();
                                  }
                                }
                              } else if (_mode == 'payment') {
                                if ((_wholesalerName ?? '').isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Select wholesaler')),
                                  );
                                } else {
                                  await app.recordWholesalerPayment(
                                    shopName: shop,
                                    wholesalerName: _wholesalerName!,
                                    amount: amt,
                                    note: _noteCtrl.text.trim().isEmpty
                                        ? null
                                        : _noteCtrl.text.trim(),
                                  );
                                  widget.onDone();
                                }
                              } else if (_mode == 'other_exp') {
                                await app.addExpense(
                                  shopName: shop,
                                  amount: amt,
                                  category: 'Misc',
                                  note: _noteCtrl.text.trim().isEmpty
                                      ? null
                                      : _noteCtrl.text.trim(),
                                );
                                widget.onDone();
                              } else if (_mode == 'emp_exp') {
                                await app.addEmployeeExpense(
                                  shopName: shop,
                                  amount: amt,
                                  type: _empType,
                                  employeeName: _employeeName,
                                  note: _noteCtrl.text.trim().isEmpty
                                      ? null
                                      : _noteCtrl.text.trim(),
                                );
                                widget.onDone();
                              }
                            } finally {
                              if (mounted) setState(() => _saving = false);
                            }
                          },
                    child: _saving
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
