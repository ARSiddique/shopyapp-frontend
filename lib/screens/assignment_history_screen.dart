import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

class AssignmentHistoryScreen extends StatefulWidget {
  final String? employeeId; // Optional parameter

  const AssignmentHistoryScreen({super.key, this.employeeId});

  @override
  State<AssignmentHistoryScreen> createState() =>
      _AssignmentHistoryScreenState();
}

class _AssignmentHistoryScreenState extends State<AssignmentHistoryScreen> {
  String? _selectedEmployeeId;
  final _dateFmt = DateFormat('dd MMM yyyy');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = Provider.of<AppDataProvider>(context);
    final user = app.loggedInUser ?? {};
    final role = (user['role'] ?? 'employee').toString().toLowerCase();

    if (widget.employeeId != null) {
      _selectedEmployeeId = widget.employeeId;
    } else if (role == 'employee') {
      _selectedEmployeeId = user['id']?.toString();
    } else {
      _selectedEmployeeId ??= 'ALL';
    }
  }

  List<Map<String, dynamic>> _getAssignmentsForSelected(
    AppDataProvider appData,
  ) {
    final all = appData.employees;
    if (_selectedEmployeeId == null) return [];

    if (_selectedEmployeeId == 'ALL') {
      return all
          .expand((emp) => _extractAssignments(emp, emp['name']))
          .toList();
    }

    final emp = all.firstWhere(
      (e) => e['id'] == _selectedEmployeeId,
      orElse: () => {},
    );
    return _extractAssignments(emp, emp['name']);
  }

  List<Map<String, dynamic>> _extractAssignments(Map emp, String empName) {
    final assignments =
        emp['assignments'] ??
        emp['assignmentHistory'] ??
        emp['shopAssignments'] ??
        [];

    return (assignments as List).map<Map<String, dynamic>>((a) {
      final rawDate = a['assignedAt'] ?? a['date'];
      DateTime? dt;
      if (rawDate is DateTime) {
        dt = rawDate;
      } else if (rawDate is String) {
        dt = DateTime.tryParse(rawDate);
      } else if (rawDate != null && rawDate.toString().contains('Timestamp')) {
        try {
          dt = rawDate.toDate();
        } catch (_) {}
      }

      return {
        'employeeName': empName,
        'shopName': a['shopName'] ?? 'Unknown',
        'date': dt ?? DateTime(2000),
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppDataProvider>(context);
    final role = (app.loggedInUser?['role'] ?? 'employee').toLowerCase();
    final assignments = _getAssignmentsForSelected(app);
    assignments.sort((a, b) => b['date'].compareTo(a['date'])); // newest first

    return Scaffold(
      appBar: AppBar(
        title: const Text("Assignment History"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          if (role != 'employee' && widget.employeeId == null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: DropdownButtonFormField<String>(
                value: _selectedEmployeeId,
                items: [
                  const DropdownMenuItem(
                    value: 'ALL',
                    child: Text("All Employees"),
                  ),
                  ...app.employees.map((e) {
                    return DropdownMenuItem(
                      value: e['id'].toString(),
                      child: Text(e['name'] ?? ''),
                    );
                  }),
                ],
                onChanged: (val) => setState(() => _selectedEmployeeId = val),
                decoration: const InputDecoration(
                  labelText: "Filter by Employee",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: assignments.isEmpty
                ? const Center(child: Text("No assignment history found."))
                : ListView.builder(
                    itemCount: assignments.length,
                    itemBuilder: (_, index) {
                      final item = assignments[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: ListTile(
                          title: Text("Shop: ${item['shopName']}"),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (role != 'employee' &&
                                  widget.employeeId == null)
                                Text("Employee: ${item['employeeName']}"),
                              Text("Date: ${_dateFmt.format(item['date'])}"),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
