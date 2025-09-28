import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

class PullAllShopOrdersScreen extends StatefulWidget {
  final DateTime date;
  const PullAllShopOrdersScreen({super.key, required this.date});

  @override
  State<PullAllShopOrdersScreen> createState() => _PullAllShopOrdersScreenState();
}

class _PullAllShopOrdersScreenState extends State<PullAllShopOrdersScreen> {
  late DateTime _anchor;
  bool _loading = true;
  Map<String, List<Map<String, dynamic>>> _data = {};

  @override
  void initState() {
    super.initState();
    _anchor = DateTime(widget.date.year, widget.date.month, widget.date.day);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final app = context.read<AppDataProvider>();
    _data = await app.pullAllShopOrdersForDate(date: _anchor);
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _shift(int deltaDays) async {
    setState(() => _anchor = _anchor.add(Duration(days: deltaDays)));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMMM d, yyyy').format(_anchor);

    return Scaffold(
      appBar: AppBar(title: const Text('Pulled Orders')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          children: [
            Row(
              children: [
                ElevatedButton(onPressed: () => _shift(-1), child: const Text('Prev')),
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
                ElevatedButton(onPressed: () => _shift(1), child: const Text('Next')),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _data.isEmpty
                      ? const Center(child: Text('No orders found'))
                      : ListView.separated(
                          itemCount: _data.keys.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final wholesaler = _data.keys.elementAt(i);
                            final items = _data[wholesaler]!;
                            return _groupCard(wholesaler, items);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupCard(String wholesaler, List<Map<String, dynamic>> items) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        title: Text(wholesaler, style: const TextStyle(fontWeight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          for (final m in items)
            Container(
              height: 56,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green.withOpacity(0.7)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(m['shopName'] ?? '')),
                  Text('\$${((m['amount'] ?? 0) as num).toStringAsFixed(2)}'),
                  const SizedBox(width: 8),
                  _statusDot(m['status']?.toString() ?? 'Pending'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusDot(String status) {
    Color c;
    switch (status) {
      case 'Received': c = Colors.green; break;
      case 'Forwarded': c = Colors.orange; break;
      default: c = Colors.grey;
    }
    return Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle));
  }
}
