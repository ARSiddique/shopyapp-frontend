import 'dart:io';
import 'package:csv/csv.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_data_provider.dart';
import 'add_sale_screen.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Provider.of<AppDataProvider>(context, listen: false).fetchSales();
  }

  Future<Directory?> _getDownloadDirectory() async {
    final contextOwner = context;

    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.request().isGranted ||
          await Permission.storage.request().isGranted) {
        final directory = Directory('/storage/emulated/0/Download');
        if (await directory.exists()) {
          return directory;
        } else {
          return await getExternalStorageDirectory(); // fallback
        }
      } else {
        if (!contextOwner.mounted) return null;
        ScaffoldMessenger.of(contextOwner).showSnackBar(
          const SnackBar(content: Text('Storage permission denied')),
        );
        return null;
      }
    } else {
      return await getApplicationDocumentsDirectory(); // for iOS or other
    }
  }

  Future<void> _deleteSale(String saleId) async {
    final contextOwner = context; // ✅ Capture early
    final appData = Provider.of<AppDataProvider>(
      contextOwner,
      listen: false,
    ); // ✅ Before await

    final confirm = await showDialog<bool>(
      context: contextOwner,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Sale?'),
        content: const Text('Are you sure you want to delete this sale?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await appData.deleteSale(saleId);

    if (!contextOwner.mounted) return;

    await appData.fetchSales();

    if (!contextOwner.mounted) return;

    setState(() {});
  }

  void _openEditSale(Map<String, dynamic> sale) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddSaleScreen(existingSale: sale)),
    );
  }

  Future<void> exportCSV(List<Map<String, dynamic>> sales) async {
    final contextOwner = context;

    final csvData = [
      [
        'Date',
        'Time',
        'Shop',
        'Cash',
        'Card',
        'Other',
        'Total',
        'Submitted By',
      ],
      ...sales.map((sale) {
        final dt = sale['createdAt'] ?? DateTime.now();
        return [
          DateFormat('yyyy-MM-dd').format(dt),
          DateFormat('hh:mm a').format(dt),
          sale['shop'] ?? '',
          (sale['cash'] ?? 0).toString(),
          (sale['card'] ?? 0).toString(),
          (sale['other'] ?? 0).toString(),
          (sale['total'] ?? 0).toString(),
          sale['employee'] ?? '',
        ];
      }),
    ];

    final csv = const ListToCsvConverter().convert(csvData);
    final directory = await _getDownloadDirectory();
    if (directory == null || !contextOwner.mounted) return;
    final path = '${directory.path}/sales_report.csv';
    final file = File(path);
    await file.writeAsString(csv);
    if (!contextOwner.mounted) return;
    ScaffoldMessenger.of(
      contextOwner,
    ).showSnackBar(SnackBar(content: Text('CSV exported to: $path')));
  }

  Future<void> exportPDF(List<Map<String, dynamic>> sales) async {
    final contextOwner = context;

    final pdf = pw.Document();
    final headers = [
      'Date',
      'Time',
      'Shop',
      'Cash',
      'Card',
      'Other',
      'Total',
      'Submitted By',
    ];

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.TableHelper.fromTextArray(
            headers: headers,
            data: sales.map((sale) {
              final dt = sale['createdAt'] ?? DateTime.now();
              return [
                DateFormat('yyyy-MM-dd').format(dt),
                DateFormat('hh:mm a').format(dt),
                sale['shop'] ?? '',
                (sale['cash'] ?? 0).toString(),
                (sale['card'] ?? 0).toString(),
                (sale['other'] ?? 0).toString(),
                (sale['total'] ?? 0).toString(),
                sale['employee'] ?? '',
              ];
            }).toList(),
          );
        },
      ),
    );

    final directory = await _getDownloadDirectory();
    if (directory == null || !contextOwner.mounted) return;
    final file = File('${directory.path}/sales_report.pdf');
    await file.writeAsBytes(await pdf.save());
    if (!contextOwner.mounted) return;
    ScaffoldMessenger.of(
      contextOwner,
    ).showSnackBar(SnackBar(content: Text('PDF exported to: ${file.path}')));
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final user = appData.loggedInUser ?? {};
    final role = user['role'] ?? 'employee';
    final isEmployee = role == 'employee';

    if (isEmployee) {
      final contextOwner = context;
      Future.delayed(Duration.zero, () {
        if (!contextOwner.mounted) return;
        Navigator.pushReplacement(
          contextOwner,
          MaterialPageRoute(builder: (_) => const AddSaleScreen()),
        );
      });
      return const SizedBox();
    }

    final sales = appData.sales;
    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('hh:mm a');
    final cashTotal = sales.fold<double>(0, (sum, s) => sum + (s['cash'] ?? 0));
    final cardTotal = sales.fold<double>(0, (sum, s) => sum + (s['card'] ?? 0));
    final otherTotal = sales.fold<double>(
      0,
      (sum, s) => sum + (s['other'] ?? 0),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Report'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export PDF',
            onPressed: () => exportPDF(sales),
          ),
          IconButton(
            icon: const Icon(Icons.table_chart),
            tooltip: 'Export CSV',
            onPressed: () => exportCSV(sales),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Sale'),
        backgroundColor: Colors.teal,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddSaleScreen()),
          );
        },
      ),
      body: sales.isEmpty
          ? const Center(child: Text('No sales data available.'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  color: Colors.teal.shade50,
                  padding: const EdgeInsets.all(12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Text(
                          '💵 Cash: Rs $cashTotal',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '💳 Card: Rs $cardTotal',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '🪙 Other: Rs $otherTotal',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 800),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            Colors.grey[300],
                          ),
                          columns: const [
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Time')),
                            DataColumn(label: Text('Shop')),
                            DataColumn(label: Text('Cash')),
                            DataColumn(label: Text('Card')),
                            DataColumn(label: Text('Other')),
                            DataColumn(label: Text('Total')),
                            DataColumn(label: Text('Submitted By')),
                          ],
                          rows: sales.map((sale) {
                            final dt = sale['createdAt'] ?? DateTime.now();
                            return DataRow(
                              cells: [
                                DataCell(Text(dateFormat.format(dt))),
                                DataCell(Text(timeFormat.format(dt))),
                                DataCell(Text(sale['shop'] ?? '-')),
                                DataCell(Text('Rs ${sale['cash'] ?? 0}')),
                                DataCell(Text('Rs ${sale['card'] ?? 0}')),
                                DataCell(Text('Rs ${sale['other'] ?? 0}')),
                                DataCell(Text('Rs ${sale['total'] ?? 0}')),
                                DataCell(
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(sale['employee'] ?? '-'),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          size: 18,
                                          color: Colors.blue,
                                        ),
                                        onPressed: () => _openEditSale(sale),
                                        tooltip: 'Edit Sale',
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          size: 18,
                                          color: Colors.red,
                                        ),
                                        onPressed: () =>
                                            _deleteSale(sale['id']),
                                        tooltip: 'Delete Sale',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
