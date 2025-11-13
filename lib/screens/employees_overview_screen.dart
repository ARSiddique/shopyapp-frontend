// lib/screens/employees_overview_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_data_provider.dart';
import 'add_employee_and_access_screen.dart';
import 'employee_expense_detail_screen.dart';

class EmployeesOverviewScreen extends StatefulWidget {
  const EmployeesOverviewScreen({super.key});

  @override
  State<EmployeesOverviewScreen> createState() => _EmployeesOverviewScreenState();
}

class _EmployeesOverviewScreenState extends State<EmployeesOverviewScreen> {
  bool _loading = false;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final app = context.read<AppDataProvider>();
      setState(() => _loading = true);
      try {
        if (app.employees.isEmpty) await app.fetchEmployees();
        if (app.shops.isEmpty) await app.fetchShops();
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _canManage(Map<String, dynamic>? me) {
    final role = (me?['role'] ?? '').toString().toLowerCase();
    return role == 'admin' || role == 'manager';
  }

  Future<void> _openAssignShopsSheet(
    BuildContext context, {
    required String uid,
    required String name,
  }) async {
    final app = Provider.of<AppDataProvider>(context, listen: false);
    final allShops = app.shops
        .where((s) => (s['isDeleted'] ?? false) != true)
        .map((s) => (s['name'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList()
      ..sort();

    final current = app.getAssignedShopsForUser(uid);
    final initialSelected = {...current};

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxHeight: 600),
      builder: (ctx) {
        Set<String> selected = {...initialSelected};
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16, right: 16, top: 8,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Assign shops to $name',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    const SizedBox(height: 8),
                    if (allShops.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text('No active shops found'),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: allShops.length,
                          itemBuilder: (_, i) {
                            final shop = allShops[i];
                            final checked = selected.contains(shop);
                            return CheckboxListTile(
                              value: checked,
                              onChanged: (v) {
                                setSheetState(() {
                                  if (v == true) {
                                    selected.add(shop);
                                  } else {
                                    selected.remove(shop);
                                  }
                                });
                              },
                              title: Text(shop),
                              controlAffinity: ListTileControlAffinity.leading,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              await app.updateShopAssignments(
                                userId: uid,
                                userName: name,
                                newAssignedShops: selected.toList(),
                              );
                              if (context.mounted) Navigator.pop(ctx);
                            },
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openEmployeeDetail(BuildContext context, {required Map<String, dynamic> emp}) {
    final name = (emp['name'] ?? '').toString();
    final role = (emp['role'] ?? '').toString().toLowerCase();
    final email = (emp['email'] ?? '').toString();
    final phone = (emp['phone'] ?? '').toString();
    final shops = (emp['assignedShops'] as List? ?? [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
    final storedPassword = (emp['password'] ?? emp['loginCode'] ?? '').toString();

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxHeight: 520),
      builder: (ctx) {
        bool showPwd = false;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16, right: 16, top: 8,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SafeArea(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name.isEmpty ? 'Unnamed' : name,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: role == 'admin'
                                ? Colors.indigo.withValues(alpha: 0.12)
                                : role == 'manager'
                                    ? Colors.orange.withValues(alpha: 0.12)
                                    : Colors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            role,
                            style: TextStyle(
                              fontSize: 12,
                              color: role == 'admin'
                                  ? Colors.indigo
                                  : role == 'manager'
                                      ? Colors.orange
                                      : Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.badge_outlined),
                            title: const Text('Name'),
                            subtitle: Text(name.isEmpty ? '—' : name),
                          ),
                          const Divider(height: 0),
                          ListTile(
                            leading: const Icon(Icons.mail_outline),
                            title: const Text('Email'),
                            subtitle: Text(email.isEmpty ? '—' : email),
                          ),
                          const Divider(height: 0),
                          ListTile(
                            leading: const Icon(Icons.phone_outlined),
                            title: const Text('Phone'),
                            subtitle: Text(phone.isEmpty ? '—' : phone),
                          ),
                          const Divider(height: 0),
                         ListTile(
  leading: const Icon(Icons.lock_outline),
  title: const Text('Password / Login Code'),
  subtitle: Text(
    storedPassword.isEmpty
        ? '—'
        : (showPwd ? storedPassword : '•' * storedPassword.length),
    style: const TextStyle(letterSpacing: 1.2),
  ),
  trailing: storedPassword.isEmpty
      ? null
      : IconButton(
          tooltip: showPwd ? 'Hide' : 'Show',
          icon: Icon(showPwd ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setSheetState(() => showPwd = !showPwd),
        ),
),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Assigned shops',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    const SizedBox(height: 8),
                    if (shops.isEmpty)
                      const Text('No shops assigned')
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: shops
                            .map((s) => Chip(label: Text(s), visualDensity: VisualDensity.compact))
                            .toList(),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _editEmployee(Map<String, dynamic> emp) async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddEmployeeAndAccessScreen(existingEmployee: emp)),
    );
  }

  Future<void> _confirmDelete(String uid, String name, String role) async {
    if (role.toLowerCase() == 'admin') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot delete an Admin'), backgroundColor: Colors.red),
      );
      return;
    }

    final app = Provider.of<AppDataProvider>(context, listen: false);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete employee?'),
        content: Text('Are you sure you want to delete “$name”? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await app.deleteEmployeeById(uid, name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppDataProvider>(context);
    final canManage = _canManage(app.loggedInUser);

    // Admin ko list se hide
    final all = app.employees
        .where((e) => (e['role'] ?? '').toString().toLowerCase() != 'admin')
        .toList();

    // Search filter
    final q = _searchCtrl.text.trim().toLowerCase();
    final items = q.isEmpty
        ? all
        : all.where((e) {
            final name = (e['name'] ?? '').toString().toLowerCase();
            final email = (e['email'] ?? '').toString().toLowerCase();
            return name.contains(q) || email.contains(q);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employees'),
        actions: [
          IconButton(
            tooltip: 'Add employee',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddEmployeeAndAccessScreen()),
              );
            },
            icon: const Icon(Icons.person_add_alt_1),
          ),
        ],
      ),
      // NOTE: Clean UX — FAB remove kiya gaya
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const SizedBox(height: 8),
                // Search bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search employee',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                if (items.isEmpty)
                  const Expanded(
                    child: Center(child: Text('No employees found')),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.2),
                      itemBuilder: (_, i) {
                        final emp = items[i];
                        final name = (emp['name'] ?? '').toString();
                        final role = (emp['role'] ?? '').toString();
                        final uid = (emp['uid'] ?? '').toString();
                        final shops = (emp['assignedShops'] as List? ?? []).cast<dynamic>()
                            .map((e) => e.toString()).where((s) => s.isNotEmpty).toList();

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          leading: CircleAvatar(
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
                              const SizedBox(width: 8),
                              _RoleChip(role: role),
                            ],
                          ),
                          subtitle: Text(
                            shops.isEmpty ? 'No shops assigned' : shops.join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PopupMenuButton<String>(
                                tooltip: 'More',
                                onSelected: (v) async {
                                  if (v == 'assign') {
                                    if (uid.isNotEmpty) {
                                      await _openAssignShopsSheet(context, uid: uid, name: name);
                                    }
                                  }
                                  if (v == 'expenses') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => EmployeeExpenseDetailScreen(
                                          employeeName: name,
                                          employee: emp,
                                        ),
                                      ),
                                    );
                                  }
                                  if (v == 'edit') {
                                    await _editEmployee(emp);
                                  }
                                  if (v == 'delete') {
                                    await _confirmDelete(uid, name, role);
                                  }
                                  if (v == 'view') {
                                    _openEmployeeDetail(context, emp: emp);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(value: 'assign', child: Text('Assign shops')),
                                  const PopupMenuItem(value: 'expenses', child: Text('Expenses')),
                                  const PopupMenuItem(value: 'view', child: Text('View info')),
                                  if (canManage) const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                  if (canManage) const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                ],
                                icon: const Icon(Icons.more_vert),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          onTap: () => _openEmployeeDetail(context, emp: emp),
                        );
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});
  final String role;

  @override
  Widget build(BuildContext context) {
    final r = (role.isEmpty ? 'employee' : role).toLowerCase();
    final Color color =
        r == 'admin' ? Colors.indigo : (r == 'manager' ? Colors.orange : Colors.green);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.12),
        shape: StadiumBorder(side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.2))),
      ),
      child: Text(r, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
