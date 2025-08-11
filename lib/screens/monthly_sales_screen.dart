import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:csv/csv.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/app_data_provider.dart';

class MonthlySalesScreen extends StatefulWidget {
  const MonthlySalesScreen({super.key});

  @override
  State<MonthlySalesScreen> createState() => _MonthlySalesScreenState();
}

class _MonthlySalesScreenState extends State<MonthlySalesScreen> {
  String? selectedShop;
  DateTime currentMonth = DateTime(DateTime.now().year, DateTime.now().month);

  void _goToPreviousMonth() {
    setState(() {
      currentMonth = DateTime(currentMonth.year, currentMonth.month - 1);
    });
  }

  void _goToNextMonth() {
    setState(() {
      currentMonth = DateTime(currentMonth.year, currentMonth.month + 1);
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
    List<DateTime> monthDates,
    Map<String, Map<String, num>> shopDaySales,
  ) async {
    final csvData = [
      ['Date', 'Cash', 'Card', 'Other', 'Total'],
      ...monthDates.map((date) {
        final key = DateFormat('yyyy-MM-dd').format(date);
        final salesData =
            shopDaySales[key] ?? {'cash': 0, 'card': 0, 'other': 0};
        final total =
            (salesData['cash'] ?? 0) +
            (salesData['card'] ?? 0) +
            (salesData['other'] ?? 0);
        return [
          DateFormat('MMM d, yyyy').format(date),
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
    final path = '${directory.path}/monthly_sales.csv';
    final file = File(path);
    await file.writeAsString(csv);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('CSV exported to: $path')));
  }

  Future<void> _exportPDF(
    List<DateTime> monthDates,
    Map<String, Map<String, num>> shopDaySales,
  ) async {
    final pdf = pw.Document();
    final headers = ['Date', 'Cash', 'Card', 'Other', 'Total'];
    final data = monthDates.map((date) {
      final key = DateFormat('yyyy-MM-dd').format(date);
      final salesData = shopDaySales[key] ?? {'cash': 0, 'card': 0, 'other': 0};
      final total =
          (salesData['cash'] ?? 0) +
          (salesData['card'] ?? 0) +
          (salesData['other'] ?? 0);
      return [
        DateFormat('MMM d, yyyy').format(date),
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
    final path = '${directory.path}/monthly_sales.pdf';
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

    final daysInMonth = List.generate(
      DateUtils.getDaysInMonth(currentMonth.year, currentMonth.month),
      (index) => DateTime(currentMonth.year, currentMonth.month, index + 1),
    );

    final filteredSales = sales.where((sale) {
      final shopMatch = selectedShop == null || sale['shop'] == selectedShop;
      final createdAt = sale['createdAt'];
      final dateMatch =
          createdAt != null &&
          createdAt is DateTime &&
          createdAt.month == currentMonth.month &&
          createdAt.year == currentMonth.year;
      return shopMatch && dateMatch;
    }).toList();

    Map<String, Map<String, num>> shopDaySales = {};
    for (var sale in filteredSales) {
      final createdAt = sale['createdAt'] as DateTime;
      final key = DateFormat('yyyy-MM-dd').format(createdAt);
      shopDaySales.putIfAbsent(key, () => {'cash': 0, 'card': 0, 'other': 0});
      shopDaySales[key]!['cash'] =
          (shopDaySales[key]!['cash'] ?? 0) + (sale['cash'] ?? 0);
      shopDaySales[key]!['card'] =
          (shopDaySales[key]!['card'] ?? 0) + (sale['card'] ?? 0);
      shopDaySales[key]!['other'] =
          (shopDaySales[key]!['other'] ?? 0) + (sale['other'] ?? 0);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Sales'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export PDF',
            onPressed: () => _exportPDF(daysInMonth, shopDaySales),
          ),
          IconButton(
            icon: const Icon(Icons.table_chart),
            tooltip: 'Export CSV',
            onPressed: () => _exportCSV(daysInMonth, shopDaySales),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
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
                  onPressed: _goToPreviousMonth,
                  child: const Text('Prev Month'),
                ),
                Text(
                  DateFormat('MMMM yyyy').format(currentMonth),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                ElevatedButton(
                  onPressed: _goToNextMonth,
                  child: const Text('Next Month'),
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
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Cash')),
                    DataColumn(label: Text('Card')),
                    DataColumn(label: Text('Other')),
                    DataColumn(label: Text('Total')),
                  ],
                  rows: daysInMonth.map((date) {
                    final key = DateFormat('yyyy-MM-dd').format(date);
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
                        DataCell(Text(DateFormat('MMM d, yyyy').format(date))),
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
