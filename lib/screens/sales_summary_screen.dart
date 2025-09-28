// lib/screens/sales_summary_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

class SalesSummaryScreen extends StatefulWidget {
  const SalesSummaryScreen({super.key});

  @override
  State<SalesSummaryScreen> createState() => _SalesSummaryScreenState();
}

class _SalesSummaryScreenState extends State<SalesSummaryScreen> {
  String viewMode = 'Daily'; // Daily | Weekly | Monthly | Yearly
  DateTime anchorDate = DateTime.now();
  bool loading = false;

  // data
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _shops = []; // [{name: ...}, ...]
  String _shopFilter = 'All';

  final _num = NumberFormat.decimalPattern(); // 12,345.00
  String f(double x) => _num.format(double.tryParse(x.toStringAsFixed(2)) ?? x);

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTimeRange _rangeForView() {
    final now = anchorDate;
    if (viewMode == 'Daily') {
      final start = DateTime(now.year, now.month, now.day);
      return DateTimeRange(start: start, end: start.add(const Duration(days: 1)));
    }
    if (viewMode == 'Weekly') {
      final monday = now.subtract(Duration(days: (now.weekday + 6) % 7));
      final start = DateTime(monday.year, monday.month, monday.day);
      return DateTimeRange(start: start, end: start.add(const Duration(days: 7)));
    }
    if (viewMode == 'Monthly') {
      final start = DateTime(now.year, now.month, 1);
      return DateTimeRange(start: start, end: DateTime(now.year, now.month + 1, 1));
    }
    final start = DateTime(now.year, 1, 1);
    return DateTimeRange(start: start, end: DateTime(now.year + 1, 1, 1));
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final app = context.read<AppDataProvider>();
    final range = _rangeForView();

    _shops = app.shops.cast<Map<String, dynamic>>();
    // Ensure "All" is always valid
    if (_shops.isEmpty) _shops = const [];
    if (_shopFilter != 'All' &&
        !_shops.any((s) => (s['name'] ?? '').toString() == _shopFilter)) {
      _shopFilter = 'All';
    }

    _sales = await app.fetchSalesBetween(
      from: range.start,
      to: range.end,
      shopName: _shopFilter == 'All' ? null : _shopFilter,
    );

    if (mounted) setState(() => loading = false);
  }

  void _shiftPeriod(int dir) {
    setState(() {
      if (viewMode == 'Daily') {
        anchorDate = anchorDate.add(Duration(days: dir));
      } else if (viewMode == 'Weekly') {
        anchorDate = anchorDate.add(Duration(days: 7 * dir));
      } else if (viewMode == 'Monthly') {
        anchorDate = DateTime(anchorDate.year, anchorDate.month + dir, 1);
      } else {
        anchorDate = DateTime(anchorDate.year + dir, 1, 1);
      }
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final df = viewMode == 'Monthly'
        ? DateFormat('MMMM yyyy')
        : (viewMode == 'Yearly' ? DateFormat('yyyy') : DateFormat('MMM dd, yyyy'));

    final allShopNames = [
      'All',
      ..._shops.map((s) => (s['name'] ?? '').toString()).where((s) => s.isNotEmpty)
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("Sales Summary")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top controls row
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // View dropdown
                      DropdownButton<String>(
                        value: viewMode,
                        items: const ['Daily', 'Weekly', 'Monthly', 'Yearly']
                            .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => viewMode = v);
                          _load();
                        },
                      ),

                      // Prev / date / next
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: () => _shiftPeriod(-1),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_month),
                            label: Text(df.format(anchorDate)),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: anchorDate,
                                firstDate: DateTime(2022, 1, 1),
                                lastDate: DateTime(2100, 1, 1),
                              );
                              if (picked != null) {
                                setState(() => anchorDate = picked);
                                _load();
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () => _shiftPeriod(1),
                          ),
                        ],
                      ),

                      // Shop filter
                      DropdownButton<String>(
                        value: _shopFilter,
                        items: allShopNames
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _shopFilter = v);
                          _load();
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 4),

                // Scrollable, compact table
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 640), // room for columns
                      child: DataTableTheme(
                        data: const DataTableThemeData(
                          dataRowMinHeight: 36,
                          dataRowMaxHeight: 36,
                          headingRowHeight: 40,
                        ),
                        child: DataTable(
                          headingTextStyle: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                          columnSpacing: 24,
                          horizontalMargin: 12,
                          columns: const [
                            DataColumn(label: Text("Shop")),
                            DataColumn(label: Text("Counted Cash")),
                            DataColumn(label: Text("Card")),
                            DataColumn(label: Text("Other")),
                            DataColumn(label: Text("Total")),
                            // DataColumn(label: Text("POS Cash")), // removed (by request)
                          ],
                          rows: _buildRows(allShopNames),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  List<DataRow> _buildRows(List<String> allShopNames) {
    // Aggregate by shop (only the selected shop if filter != All)
    final byShop = <String, Map<String, double>>{};

    for (final m in _sales) {
      final shop = (m['shopName'] ?? m['shop'] ?? '').toString();
      if (shop.isEmpty) continue;

      final countedCash = _pickAmount(m, const [
        'countedCash', 'counted_cash', 'cashCounted', 'cash_counted', 'cash'
      ]);
      final card = _pickAmount(m, const ['card', 'cardAmount', 'card_amount']);
      final other = _pickAmount(m, const ['other', 'otherAmount', 'other_amount']);

      // POS/System cash (not used now)
      // final posCash = _pickAmount(m, const [
      //   'posCash', 'pos_cash', 'cashPos', 'cash_pos', 'systemCash', 'system_cash'
      // ], fallback: null);

      final total = countedCash + card + other;

      byShop.putIfAbsent(shop, () => {
            'counted': 0,
            'card': 0,
            'other': 0,
            'total': 0,
            // 'pos': 0,
          });
      byShop[shop]!['counted'] = byShop[shop]!['counted']! + countedCash;
      byShop[shop]!['card'] = byShop[shop]!['card']! + card;
      byShop[shop]!['other'] = byShop[shop]!['other']! + other;
      byShop[shop]!['total'] = byShop[shop]!['total']! + total;
      // byShop[shop]!['pos'] = byShop[shop]!['pos']! + (posCash ?? 0);
    }

    // Build list of shops to show
    final shopsToShow = (_shopFilter == 'All'
            ? _shops.map((s) => (s['name'] ?? '').toString())
            : <String>[_shopFilter])
        .where((s) => s.isNotEmpty)
        .toList()
      ..sort();

    // Always include a row even if zero
    for (final s in shopsToShow) {
      byShop.putIfAbsent(s, () => {
            'counted': 0,
            'card': 0,
            'other': 0,
            'total': 0,
            // 'pos': 0,
          });
    }

    // Build rows + totals
    final rows = <DataRow>[];
    double tCounted = 0, tCard = 0, tOther = 0, tTotal = 0;
    // double tPos = 0;

    for (final s in shopsToShow) {
      final v = byShop[s]!;
      tCounted += v['counted']!;
      tCard += v['card']!;
      tOther += v['other']!;
      tTotal += v['total']!;
      // tPos += v['pos']!;

      rows.add(
        DataRow(
          cells: [
            _cellLeft(s),
            _cellRight(f(v['counted']!)),
            _cellRight(f(v['card']!)),
            _cellRight(f(v['other']!)),
            _cellRight(f(v['total']!)),
            // _cellRight(f(v['pos']!)),
          ],
        ),
      );
    }

    // Totals row
    rows.add(
      DataRow(
        cells: [
          _cellLeft('Total', bold: true),
          _cellRight(f(tCounted), bold: true),
          _cellRight(f(tCard), bold: true),
          _cellRight(f(tOther), bold: true),
          _cellRight(f(tTotal), bold: true),
          // _cellRight(f(tPos), bold: true),
        ],
      ),
    );

    return rows;
  }

  DataCell _cellLeft(String text, {bool bold = false}) {
    return DataCell(
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: bold
              ? Theme.of(context).textTheme.titleMedium
              : Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }

  DataCell _cellRight(String text, {bool bold = false}) {
    return DataCell(
      Align(
        alignment: Alignment.centerRight,
        child: Text(
          text,
          style: bold
              ? Theme.of(context).textTheme.titleMedium
              : Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }

  // Try multiple keys; if none present, returns 0 or fallback if provided
  double _pickAmount(Map<String, dynamic> m, List<String> keys, {double? fallback}) {
    for (final k in keys) {
      if (m.containsKey(k) && m[k] != null) return _toDouble(m[k]);
    }
    if (fallback != null) return fallback;
    return 0.0;
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}
