import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:csv/csv.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/app_data_provider.dart';

class WeeklySalesScreen extends StatefulWidget {
  const WeeklySalesScreen({super.key});

  @override
  State<WeeklySalesScreen> createState() => _WeeklySalesScreenState();
}

class _WeeklySalesScreenState extends State<WeeklySalesScreen> {
  String? selectedShop;
  DateTime currentWeekStart = _getStartOfWeek(DateTime.now());

  static DateTime _getStartOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  void _goToPreviousWeek() {
    setState(() {
      currentWeekStart = currentWeekStart.subtract(const Duration(days: 7));
    });
  }

  void _goToNextWeek() {
    setState(() {
      currentWeekStart = currentWeekStart.add(const Duration(days: 7));
    });
  }

  Future<Directory?> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.request().isGranted ||
          await Permission.storage.request().isGranted) {
        final directory = Directory('/storage/emulated/0/Download');
        if (await directory.exists()) {
          return directory;
        } else {
          return await getExternalStorageDirectory();
        }
      } else {
        if (!mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission denied')),
        );
        return null;
      }
    } else {
      final dir = await getApplicationDocumentsDirectory();
      if (!mounted) return null;
      return dir;
    }
  }

  Future<void> _exportCSV(
    List<DateTime> weekDates,
    Map<String, Map<String, num>> shopDaySales,
  ) async {
    final csvData = [
      ['Day', 'Cash', 'Card', 'Other', 'Total'],
      ...weekDates.map((day) {
        final key = DateFormat('yyyy-MM-dd').format(day);
        final salesData =
            shopDaySales[key] ?? {'cash': 0, 'card': 0, 'other': 0};
        final total =
            (salesData['cash'] ?? 0) +
            (salesData['card'] ?? 0) +
            (salesData['other'] ?? 0);
        return [
          DateFormat('EEE, MMM d').format(day),
          '${salesData['cash']}',
          '${salesData['card']}',
          '${salesData['other']}',
          '$total',
        ];
      }),
    ];

    final csv = const ListToCsvConverter().convert(csvData);
    final directory = await _getDownloadDirectory();
    if (!mounted) return;
    if (directory == null) return;
    final path = '${directory.path}/weekly_sales.csv';
    final file = File(path);
    await file.writeAsString(csv);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('CSV exported to: $path')));
  }

  Future<void> _exportPDF(
    List<DateTime> weekDates,
    Map<String, Map<String, num>> shopDaySales,
  ) async {
    final pdf = pw.Document();
    final headers = ['Day', 'Cash', 'Card', 'Other', 'Total'];
    final data = weekDates.map((day) {
      final key = DateFormat('yyyy-MM-dd').format(day);
      final salesData = shopDaySales[key] ?? {'cash': 0, 'card': 0, 'other': 0};
      final total =
          (salesData['cash'] ?? 0) +
          (salesData['card'] ?? 0) +
          (salesData['other'] ?? 0);
      return [
        DateFormat('EEE, MMM d').format(day),
        '${salesData['cash']}',
        '${salesData['card']}',
        '${salesData['other']}',
        '$total',
      ];
    }).toList();

    pdf.addPage(
      pw.Page(
        build: (context) =>
            pw.TableHelper.fromTextArray(headers: headers, data: data),
      ),
    );

    final directory = await _getDownloadDirectory();
    if (!mounted) return;
    if (directory == null) return;
    final path = '${directory.path}/weekly_sales.pdf';
    final file = File(path);
    await file.writeAsBytes(await pdf.save());
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('PDF exported to: $path')));
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final sales = appData.sales;
    final shops = appData.shops;
    final weekDates = List.generate(
      7,
      (i) => currentWeekStart.add(Duration(days: i)),
    );
    final dateFormat = DateFormat('EEE, MMM d');

    final filteredSales = sales.where((sale) {
      final shopMatch = selectedShop == null || sale['shop'] == selectedShop;
      final createdAt = sale['createdAt'];
      final dateMatch =
          createdAt != null &&
          createdAt is DateTime &&
          createdAt.isAfter(
            currentWeekStart.subtract(const Duration(days: 1)),
          ) &&
          createdAt.isBefore(currentWeekStart.add(const Duration(days: 7)));
      return shopMatch && dateMatch;
    }).toList();

    Map<String, Map<String, num>> shopDaySales = {};
    for (var sale in filteredSales) {
      final createdAt = sale['createdAt'] as DateTime;
      final day = DateFormat('yyyy-MM-dd').format(createdAt);
      shopDaySales.putIfAbsent(day, () => {'cash': 0, 'card': 0, 'other': 0});
      shopDaySales[day]!['cash'] =
          (shopDaySales[day]!['cash'] ?? 0) + (sale['cash'] ?? 0);
      shopDaySales[day]!['card'] =
          (shopDaySales[day]!['card'] ?? 0) + (sale['card'] ?? 0);
      shopDaySales[day]!['other'] =
          (shopDaySales[day]!['other'] ?? 0) + (sale['other'] ?? 0);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Sales'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export PDF',
            onPressed: () => _exportPDF(weekDates, shopDaySales),
          ),
          IconButton(
            icon: const Icon(Icons.table_chart),
            tooltip: 'Export CSV',
            onPressed: () => _exportCSV(weekDates, shopDaySales),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Select Shop: '),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: selectedShop,
                  hint: const Text('Choose Shop'),
                  items: shops.map<DropdownMenuItem<String>>((s) {
                    return DropdownMenuItem<String>(
                      value: s['name'] as String,
                      child: Text(s['name']),
                    );
                  }).toList(),
                  onChanged: (String? value) {
                    setState(() => selectedShop = value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: _goToPreviousWeek,
                  child: const Text('Prev Week'),
                ),
                Text(
                  '${dateFormat.format(weekDates.first)} - ${dateFormat.format(weekDates.last)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                ElevatedButton(
                  onPressed: _goToNextWeek,
                  child: const Text('Next Week'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Colors.grey[200]),
                  columns: const [
                    DataColumn(label: Text('Day')),
                    DataColumn(label: Text('Cash')),
                    DataColumn(label: Text('Card')),
                    DataColumn(label: Text('Other')),
                    DataColumn(label: Text('Total')),
                  ],
                  rows: weekDates.map((day) {
                    final key = DateFormat('yyyy-MM-dd').format(day);
                    final salesData =
                        shopDaySales[key] ?? {'cash': 0, 'card': 0, 'other': 0};
                    final total =
                        (salesData['cash'] ?? 0) +
                        (salesData['card'] ?? 0) +
                        (salesData['other'] ?? 0);
                    return DataRow(
                      color: WidgetStateProperty.all(
                        total == 0 ? Colors.red[100] : null,
                      ),
                      cells: [
                        DataCell(Text(dateFormat.format(day))),
                        DataCell(Text('Rs ${salesData['cash']}')),
                        DataCell(Text('Rs ${salesData['card']}')),
                        DataCell(Text('Rs ${salesData['other']}')),
                        DataCell(Text('Rs $total')),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
