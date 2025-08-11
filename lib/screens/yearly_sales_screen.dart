import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:csv/csv.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/widgets.dart' show TableHelper;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/app_data_provider.dart';

class YearlySalesScreen extends StatefulWidget {
  const YearlySalesScreen({super.key});

  @override
  State<YearlySalesScreen> createState() => _YearlySalesScreenState();
}

class _YearlySalesScreenState extends State<YearlySalesScreen> {
  String? selectedShop;
  int selectedYear = DateTime.now().year;

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
      return await getApplicationDocumentsDirectory();
    }
  }

  Future<void> _exportCSV(Map<int, Map<String, num>> monthlySales) async {
    final csvData = [
      ['Month', 'Cash', 'Card', 'Other', 'Total'],
      ...monthlySales.entries.map((entry) {
        final monthName = DateFormat(
          'MMMM',
        ).format(DateTime(selectedYear, entry.key));
        final sales = entry.value;
        final total =
            (sales['cash'] ?? 0) + (sales['card'] ?? 0) + (sales['other'] ?? 0);
        return [
          monthName,
          '${sales['cash']}',
          '${sales['card']}',
          '${sales['other']}',
          '$total',
        ];
      }),
    ];
    final csv = const ListToCsvConverter().convert(csvData);
    final directory = await _getDownloadDirectory();
    if (directory == null) return;
    final file = File('${directory.path}/yearly_sales_$selectedYear.csv');
    await file.writeAsString(csv);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('CSV exported to: ${file.path}')));
  }

  Future<void> _exportPDF(Map<int, Map<String, num>> monthlySales) async {
    final pdf = pw.Document();
    final headers = ['Month', 'Cash', 'Card', 'Other', 'Total'];
    final data = monthlySales.entries.map((entry) {
      final monthName = DateFormat(
        'MMMM',
      ).format(DateTime(selectedYear, entry.key));
      final sales = entry.value;
      final total =
          (sales['cash'] ?? 0) + (sales['card'] ?? 0) + (sales['other'] ?? 0);
      return [
        monthName,
        '${sales['cash']}',
        '${sales['card']}',
        '${sales['other']}',
        '$total',
      ];
    }).toList();

    pdf.addPage(
      pw.Page(
        build: (context) =>
            TableHelper.fromTextArray(headers: headers, data: data),
      ),
    );

    final directory = await _getDownloadDirectory();
    if (directory == null) return;
    final file = File('${directory.path}/yearly_sales_$selectedYear.pdf');
    await file.writeAsBytes(await pdf.save());
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('PDF exported to: ${file.path}')));
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final sales = appData.sales;
    final shops = appData.shops;

    final filteredSales = sales.where((sale) {
      final createdAt = sale['createdAt'];
      final shopMatch = selectedShop == null || sale['shop'] == selectedShop;
      final yearMatch =
          createdAt != null &&
          createdAt is DateTime &&
          createdAt.year == selectedYear;
      return shopMatch && yearMatch;
    }).toList();

    Map<int, Map<String, num>> monthlySales = {}; // 1 to 12
    for (var sale in filteredSales) {
      final createdAt = sale['createdAt'] as DateTime;
      final month = createdAt.month;
      monthlySales.putIfAbsent(month, () => {'cash': 0, 'card': 0, 'other': 0});
      monthlySales[month]!['cash'] =
          (monthlySales[month]!['cash'] ?? 0) + (sale['cash'] ?? 0);
      monthlySales[month]!['card'] =
          (monthlySales[month]!['card'] ?? 0) + (sale['card'] ?? 0);
      monthlySales[month]!['other'] =
          (monthlySales[month]!['other'] ?? 0) + (sale['other'] ?? 0);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yearly Sales'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export PDF',
            onPressed: () => _exportPDF(monthlySales),
          ),
          IconButton(
            icon: const Icon(Icons.table_chart),
            tooltip: 'Export CSV',
            onPressed: () => _exportCSV(monthlySales),
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
                      value: s['name'],
                      child: Text(s['name']),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => selectedShop = value),
                ),
                const SizedBox(width: 32),
                const Text('Select Year: '),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: selectedYear,
                  items: List.generate(5, (i) => DateTime.now().year - i).map((
                    year,
                  ) {
                    return DropdownMenuItem<int>(
                      value: year,
                      child: Text(year.toString()),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => selectedYear = value!),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Colors.grey[300]),
                  columns: const [
                    DataColumn(label: Text('Month')),
                    DataColumn(label: Text('Cash')),
                    DataColumn(label: Text('Card')),
                    DataColumn(label: Text('Other')),
                    DataColumn(label: Text('Total')),
                  ],
                  rows: List.generate(12, (i) {
                    final month = i + 1;
                    final sales =
                        monthlySales[month] ??
                        {'cash': 0, 'card': 0, 'other': 0};
                    final total =
                        (sales['cash'] ?? 0) +
                        (sales['card'] ?? 0) +
                        (sales['other'] ?? 0);
                    return DataRow(
                      color: WidgetStateProperty.all(
                        total == 0 ? Colors.red[100] : null,
                      ),
                      cells: [
                        DataCell(
                          Text(
                            DateFormat(
                              'MMMM',
                            ).format(DateTime(selectedYear, month)),
                          ),
                        ),
                        DataCell(Text('Rs ${sales['cash']}')),
                        DataCell(Text('Rs ${sales['card']}')),
                        DataCell(Text('Rs ${sales['other']}')),
                        DataCell(Text('Rs $total')),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
