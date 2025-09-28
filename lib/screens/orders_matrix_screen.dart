import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/app_data_provider.dart';
import 'pull_all_shop_orders_screen.dart';

const double _kCellHeight = 56;

class OrdersMatrixScreen extends StatefulWidget {
  const OrdersMatrixScreen({super.key});

  @override
  State<OrdersMatrixScreen> createState() => _OrdersMatrixScreenState();
}

class _OrdersMatrixScreenState extends State<OrdersMatrixScreen> {
  DateTime _anchor = DateTime.now();
  bool _loading = true;

  // wholesaler paging (show one column like PPT/screenshot)
  int _whIndex = 0;
  List<String> _wholesalers = const [];

  // matrix[shop][wholesaler] = {...}
  Map<String, Map<String, Map<String, dynamic>>> _matrix = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prime());
  }

  Future<void> _prime() async {
    final app = context.read<AppDataProvider>();
    await app.fetchShops();
    await app.fetchWholesalers();

    // Make simple list of names
    _wholesalers = app.wholesalers.map((w) => (w['name'] ?? '').toString()).toList();
    if (_wholesalers.isEmpty) _wholesalers = ['—']; // placeholder

    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final app = context.read<AppDataProvider>();
    final selectedWh = _wholesalers[_whIndex];
    _matrix = await app.ordersMatrixForDate(
      date: DateTime(_anchor.year, _anchor.month, _anchor.day),
      wholesalersFilter: selectedWh == '—' ? null : [selectedWh],
    );
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _shiftDay(int delta) async {
    setState(() => _anchor = _anchor.add(Duration(days: delta)));
    await _load();
  }

  void _prevWh() async {
    if (_wholesalers.isEmpty) return;
    setState(() => _whIndex = (_whIndex - 1) % _wholesalers.length);
    await _load();
  }

  void _nextWh() async {
    if (_wholesalers.isEmpty) return;
    setState(() => _whIndex = (_whIndex + 1) % _wholesalers.length);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();
    final shopsList = [
      ...app.shops.map((s) => (s['name'] ?? '').toString()),
      ..._matrix.keys, // ensure any shops with orders but not in shops collection
    ].toSet().toList()
      ..sort((a, b) => a.toString().toLowerCase().compareTo(b.toString().toLowerCase()));

    final dateStr = DateFormat('MMMM d, yyyy').format(_anchor);
    final whName = _wholesalers.isEmpty ? '' : _wholesalers[_whIndex];

    return Scaffold(
      appBar: AppBar(title: const Text('Orders Matrix')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          child: SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PullAllShopOrdersScreen(date: _anchor)),
                );
              },
              icon: const Icon(Icons.list_alt_rounded),
              label: const Text('Pull all shop orders'),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Column(
            children: [
              // date nav
              Row(
                children: [
                  _pillBtn('Prev', onTap: () => _shiftDay(-1)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(dateStr, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _pillBtn('Next', onTap: () => _shiftDay(1)),
                ],
              ),
              const SizedBox(height: 12),

              // header row: Shop | wholesaler selector (prev/next)
              Row(
                children: [
                  Expanded(child: _headerCell('Shop')),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: _headerCell(whName.isEmpty ? 'Wholesaler' : whName)),
                        const SizedBox(width: 6),
                        _squareIconBtn(Icons.chevron_left, _prevWh),
                        const SizedBox(width: 6),
                        _squareIconBtn(Icons.chevron_right, _nextWh),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                        itemCount: shopsList.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final shop = shopsList[i];
                          final has = _matrix[shop] != null &&
                              _matrix[shop]![whName] != null;
                          return Row(
                            children: [
                              Expanded(child: _cell(text: shop)),
                              const SizedBox(width: 10),
                              Expanded(child: _cellIcon(has)),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pillBtn(String label, {required VoidCallback onTap}) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _headerCell(String text) {
    return Container(
      height: _kCellHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  Widget _cell({required String text}) {
    return Container(
      height: _kCellHeight,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text),
    );
  }

  Widget _cellIcon(bool hasOrder) {
    final icon = hasOrder ? Icons.check_circle : Icons.cancel_rounded;
    final color = hasOrder ? Colors.green : Colors.grey;
    return Container(
      height: _kCellHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color),
    );
  }

  Widget _squareIconBtn(IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: 44,
      height: 44,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Icon(icon),
      ),
    );
  }
}
