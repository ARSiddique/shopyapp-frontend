import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';
import 'employee_expense_detail_screen.dart';

class EmployeeExpenseListScreen extends StatefulWidget {
  const EmployeeExpenseListScreen({super.key});

  @override
  State<EmployeeExpenseListScreen> createState() => _EmployeeExpenseListScreenState();
}

class _EmployeeExpenseListScreenState extends State<EmployeeExpenseListScreen> {
  bool _loading = false;
  List<Map<String, dynamic>> _employees = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final app = context.read<AppDataProvider>();
    try {
      await app.fetchEmployees();
      setState(() {
        _employees = app.employees;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load employees')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _employees.where((e) {
      final n = (e['name'] ?? '').toString().toLowerCase();
      return n.contains(_query.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Employees')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search employee',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final e = filtered[i];
                      final name = (e['name'] ?? 'Employee').toString();
                      final salary = _toDouble(e['salary']);
                      return ListTile(
                        title: Text(name),
                        subtitle: salary > 0 ? Text('Salary: ${salary.toStringAsFixed(2)}') : null,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EmployeeExpenseDetailScreen(
                                employeeName: name,
                                employee: e,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}
