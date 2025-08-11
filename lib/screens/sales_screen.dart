import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/widgets.dart' show TableHelper;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../providers/app_data_provider.dart';
import 'add_sale_screen.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});
  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  String viewMode = 'Daily';
  DateTime selectedDate = DateTime.now();
  DateTime? fromDate;
  DateTime? toDate;
  String selectedShop = 'All';

  // ---- date window helpers (inclusive start, exclusive end) ----
  ({DateTime? from, DateTime? to}) _range() {
    final d = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    if (viewMode == 'Daily') {
      return (from: d, to: d.add(const Duration(days: 1)));
    } else if (viewMode == 'Weekly') {
      final mon = d.subtract(Duration(days: d.weekday - 1));
      return (from: mon, to: mon.add(const Duration(days: 7)));
    } else if (viewMode == 'Monthly') {
      final first = DateTime(d.year, d.month, 1);
      final nextFirst = DateTime(d.year, d.month + 1, 1);
      return (from: first, to: nextFirst);
    } else if (viewMode == 'Yearly') {
      final jan1 = DateTime(d.year, 1, 1);
      final nextJan1 = DateTime(d.year + 1, 1, 1);
      return (from: jan1, to: nextJan1);
    } else if (viewMode == 'Custom' && fromDate != null && toDate != null) {
      final start = DateTime(fromDate!.year, fromDate!.month, fromDate!.day);
      final endExclusive = DateTime(toDate!.year, toDate!.month, toDate!.day)
          .add(const Duration(days: 1));
      return (from: start, to: endExclusive);
    }
    return (from: null, to: null);
  }

  // ---- back handling (AppBar + Android back) ----
  Future<bool> _handleBack() async {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return false;
    }
    return true;
  }

  DateTime _asDate(dynamic raw) {
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
    try {
      final fn = raw?.toDate as DateTime Function();
      return fn();
    } catch (_) {
      return DateTime.now();
    }
  }

  bool _isLate(Map<String, dynamic> s) {
    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day, 21);
    return _asDate(s['createdAt']).isAfter(cutoff);
  }

  Future<Directory?> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.request().isGranted ||
          await Permission.storage.request().isGranted) {
        final dir = Directory('/storage/emulated/0/Download');
        return await dir.exists() ? dir : await getExternalStorageDirectory();
      }
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage permission denied')),
      );
      return null;
    }
    return await getApplicationDocumentsDirectory();
  }

  Future<void> _exportData(String format, List<Map<String, dynamic>> sales) async {
    final headers = ['Date', 'Time', 'Shop', 'Cash', 'Card', 'Other', 'Total', 'Submitted By'];
    String numStr(v) => (v is num) ? v.toStringAsFixed(0) : (v?.toString() ?? '0');

    final rows = sales.map((s) {
      final dt = _asDate(s['createdAt']);
      return [
        DateFormat('yyyy-MM-dd').format(dt),
        DateFormat('hh:mm a').format(dt),
        (s['shop'] ?? '').toString(),
        numStr(s['cash']),
        numStr(s['card']),
        numStr(s['other']),
        numStr(s['total']),
        (s['employee'] ?? '').toString(),
      ];
    }).toList();

    final dir = await _getDownloadDirectory();
    if (dir == null) return;
    final filePath = '${dir.path}/sales_export.${format == 'csv' ? 'csv' : 'pdf'}';

    if (format == 'csv') {
      final csv = const ListToCsvConverter().convert([headers, ...rows]);
      await File(filePath).writeAsString(csv);
    } else {
      final pdf = pw.Document();
      pdf.addPage(pw.Page(build: (_) => TableHelper.fromTextArray(headers: headers, data: rows)));
      await File(filePath).writeAsBytes(await pdf.save());
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${format.toUpperCase()} exported to: $filePath')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();
    final role = (app.loggedInUser?['role'] ?? 'employee').toString().toLowerCase();

    // employees don’t stay here
    if (role == 'employee') {
      Future.microtask(() {
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AddSaleScreen()));
      });
      return const SizedBox.shrink();
    }

    final shops = app.shops.where((s) => s['isDeleted'] != true).toList();
    final range = _range();

    // --- SERVER-SIDE STREAM (fast) ---
    final salesStream = app
        .buildSalesQuery(
          from: range.from,
          to: range.to,
          shop: selectedShop != 'All' ? selectedShop : null,
        )
        .snapshots();

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: Navigator.of(context).canPop(),
          leading: Navigator.of(context).canPop()
              ? BackButton(onPressed: _handleBack)
              : null,
          title: const Text('Sales Overview'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_shopping_cart_outlined),
              tooltip: 'Add Sale',
              onPressed: () {
                final prefillShop = selectedShop != 'All' ? selectedShop : null;
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AddSaleScreen(shopName: prefillShop)),
                );
              },
            ),
          ],
        ),

        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: const Text('Add Sale'),
          onPressed: () {
            final prefillShop = selectedShop != 'All' ? selectedShop : null;
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AddSaleScreen(shopName: prefillShop)),
            );
          },
        ),

        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Filters ----
            Padding(
              padding: const EdgeInsets.all(12),
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
                      DropdownMenuItem(value: 'Custom', child: Text('Custom')),
                    ],
                    onChanged: (v) => setState(() => viewMode = v ?? 'Daily'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => selectedDate = picked);
                    },
                    child: const Text('Pick Date'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final from = await showDatePicker(
                        context: context,
                        initialDate: fromDate ?? DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now(),
                      );
                      if (from == null) return;
                      final to = await showDatePicker(
                        context: context,
                        initialDate: toDate ?? DateTime.now(),
                        firstDate: from,
                        lastDate: DateTime.now(),
                      );
                      if (to == null) return;
                      setState(() {
                        fromDate = from;
                        toDate = to;
                        viewMode = 'Custom';
                      });
                    },
                    child: const Text('Select Range'),
                  ),
                  DropdownButton<String>(
                    value: selectedShop,
                    items: [
                      const DropdownMenuItem(value: 'All', child: Text('All Shops')),
                      ...shops.map((s) => DropdownMenuItem(
                            value: s['name'].toString(),
                            child: Text(s['name'].toString()),
                          )),
                    ],
                    onChanged: (v) => setState(() => selectedShop = v ?? 'All'),
                  ),
                ],
              ),
            ),

            // ---- Live table ----
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: salesStream,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}'));
                  }
                  final docs = snap.data?.docs ?? const [];
                  final sales = docs
                      .map((d) => context.read<AppDataProvider>().mapSaleDoc(d))
                      .toList();

                  if (sales.isEmpty) {
                    return const Center(child: Text('No sales for selected filter'));
                  }

                  return Column(
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12, bottom: 8),
                          child: Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.picture_as_pdf),
                                tooltip: 'Export PDF',
                                onPressed: () => _exportData('pdf', sales),
                              ),
                              IconButton(
                                icon: const Icon(Icons.table_chart),
                                tooltip: 'Export CSV',
                                onPressed: () => _exportData('csv', sales),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: PaginatedDataTable(
                            header: const Text('Sales Data'),
                            columns: const [
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Total')),
                              DataColumn(label: Text('Cash')),
                              DataColumn(label: Text('Card')),
                              DataColumn(label: Text('Other')),
                              DataColumn(label: Text('Shop')),
                              DataColumn(label: Text('Employee')),
                              DataColumn(label: Text('Actions')),
                            ],
                            source: _SalesDataSource(
                              sales,
                              (sale) => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => AddSaleScreen(existingSale: sale)),
                              ),
                              (id) async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Delete Sale?'),
                                    content: const Text('Are you sure you want to delete this sale?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await context.read<AppDataProvider>().deleteSale(id);
                                }
                              },
                              _isLate,
                            ),
                            rowsPerPage: sales.length < 10 ? sales.length : 10,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SalesDataSource extends DataTableSource {
  final List<Map<String, dynamic>> sales;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(String) onDelete;
  final bool Function(Map<String, dynamic>) isLate;

  _SalesDataSource(this.sales, this.onEdit, this.onDelete, this.isLate);

  DateTime _asDate(dynamic raw) {
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
    try {
      final fn = raw?.toDate as DateTime Function();
      return fn();
    } catch (_) {
      return DateTime.now();
    }
  }

  String numStr(v) => (v is num) ? v.toStringAsFixed(0) : (v?.toString() ?? '0');

  @override
  DataRow? getRow(int index) {
    if (index >= sales.length) return null;
    final s = sales[index];
    final dt = _asDate(s['createdAt']);

    return DataRow(
      color: MaterialStateProperty.resolveWith<Color?>(
        (states) => isLate(s) ? const Color.fromARGB(25, 255, 0, 0) : null,
      ),
      cells: [
        DataCell(Text(DateFormat('MMM dd, yyyy').format(dt))),
        DataCell(Text(numStr(s['total']))),
        DataCell(Text(numStr(s['cash']))),
        DataCell(Text(numStr(s['card']))),
        DataCell(Text(numStr(s['other']))),
        DataCell(Text((s['shop'] ?? '').toString())),
        DataCell(Text((s['employee'] ?? '').toString())),
        DataCell(Row(
          children: [
            IconButton(icon: const Icon(Icons.edit, size: 18, color: Colors.blue),  onPressed: () => onEdit(s)),
            IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => onDelete(s['id'].toString())),
          ],
        )),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => sales.length;
  @override
  int get selectedRowCount => 0;
}
