import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shopy_app/providers/app_data_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String selectedFilter = 'Daily';
  Future<void> _exportSalesToPDF(List<Map<String, dynamic>> sales) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Text("Sales Report", style: pw.TextStyle(fontSize: 24)),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: ["Shop", "Date", "Amount", "Payment Type"],
                data: sales.map((sale) {
                  return [
                    sale['shopName'] ?? '',
                    sale['timestamp'] != null
                        ? (sale['timestamp'] as Timestamp)
                              .toDate()
                              .toString()
                              .split(' ')[0]
                        : '',
                    sale['amount'].toString(),
                    sale['paymentType'] ?? '',
                  ];
                }).toList(),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Future<void> _exportSalesToCSV(List<Map<String, dynamic>> sales) async {
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage permission denied')),
      );
      return;
    }

    List<List<dynamic>> rows = [
      ["Shop", "Date", "Amount", "Payment Type"],
    ];

    for (var sale in sales) {
      rows.add([
        sale['shopName'] ?? '',
        sale['timestamp'] != null
            ? (sale['timestamp'] as Timestamp).toDate().toString().split(' ')[0]
            : '',
        sale['amount'] ?? '',
        sale['paymentType'] ?? '',
      ]);
    }

    String csvData = const ListToCsvConverter().convert(rows);
    final directory = await getExternalStorageDirectory();
    final path =
        "${directory!.path}/sales_report_${DateTime.now().millisecondsSinceEpoch}.csv";

    final file = File(path);
    await file.writeAsString(csvData);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('✅ CSV exported to: $path')));
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final filteredSales = appData.getFilteredSales(selectedFilter);
    final totals = appData.getFilteredTotals(selectedFilter);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Sales Reports"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 🔘 Filter Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: ['Daily', 'Weekly', 'Monthly'].map((filter) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: selectedFilter == filter,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => selectedFilter = filter);
                      }
                    },
                    selectedColor: Colors.deepPurple,
                    backgroundColor: Colors.grey[300],
                    labelStyle: TextStyle(
                      color: selectedFilter == filter
                          ? Colors.white
                          : Colors.black,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // 📊 Bar Chart
            if (filteredSales.isNotEmpty)
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: true),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < filteredSales.length) {
                              final date = DateFormat(
                                'd',
                              ).format(filteredSales[index]['date'].toDate());
                              return Text(date);
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    barGroups: List.generate(filteredSales.length, (index) {
                      final sale = filteredSales[index];
                      final total =
                          (sale['cash'] ?? 0) +
                          (sale['card'] ?? 0) +
                          (sale['other'] ?? 0);
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: total.toDouble(),
                            color: Colors.deepPurple,
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // 💰 Totals Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ReportCard(
                  label: "Cash",
                  amount: num.tryParse(totals['cash']?.toString() ?? '0'),
                  color: Colors.green,
                ),
                _ReportCard(
                  label: "Card",
                  amount: num.tryParse(totals['card']?.toString() ?? '0'),
                  color: Colors.orange,
                ),
                _ReportCard(
                  label: "Other",
                  amount: num.tryParse(totals['other']?.toString() ?? '0'),
                  color: Colors.blue,
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Recent Entries",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text("Export PDF"),
                  onPressed: () {
                    final filteredSales = Provider.of<AppDataProvider>(
                      context,
                      listen: false,
                    ).getFilteredSales(selectedFilter);
                    _exportSalesToPDF(filteredSales);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),

                ElevatedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text("Export CSV"),
                  onPressed: () {
                    final filteredSales = appData.getFilteredSales(
                      selectedFilter,
                    );
                    _exportSalesToCSV(filteredSales);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              child: filteredSales.isEmpty
                  ? const Center(child: Text("No sales found."))
                  : ListView.separated(
                      itemCount: filteredSales.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (_, index) {
                        final sale = filteredSales[index];
                        final date = sale['date']?.toDate();
                        final total =
                            (sale['cash'] ?? 0) +
                            (sale['card'] ?? 0) +
                            (sale['other'] ?? 0);
                        return ListTile(
                          leading: const Icon(Icons.point_of_sale),
                          title: Text(sale['shop'] ?? "Unknown Shop"),
                          subtitle: Text(
                            "Date: ${DateFormat.yMMMd().format(date)}",
                          ),
                          trailing: Text("Rs. ${total.toStringAsFixed(0)}"),
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

class _ReportCard extends StatelessWidget {
  final String label;
  final num? amount;
  final Color color;

  const _ReportCard({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withAlpha((0.1 * 255).round()),
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text("Rs. ${amount?.toStringAsFixed(0) ?? '0'}"),
          ],
        ),
      ),
    );
  }
}
