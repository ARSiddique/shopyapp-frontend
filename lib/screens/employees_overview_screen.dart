// lib/screens/employees_overview_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';
import 'add_employee_and_access_screen.dart';

class EmployeesOverviewScreen extends StatefulWidget {
  const EmployeesOverviewScreen({super.key});

  @override
  State<EmployeesOverviewScreen> createState() => _EmployeesOverviewScreenState();
}

class _EmployeesOverviewScreenState extends State<EmployeesOverviewScreen> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final app = Provider.of<AppDataProvider>(context, listen: false);
      setState(() => _loading = true);
      if (app.employees.isEmpty) await app.fetchUsers();
      if (app.shops.isEmpty) await app.fetchShops();
      setState(() => _loading = false);
    });
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
                                  if (v == true) selected.add(shop);
                                  else selected.remove(shop);
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
                              if (context.mounted) Navigator.pop(ctx); // auto-close
                              // (no snackbar on purpose)
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
                  // Header
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
                              ? Colors.indigo.withOpacity(0.12)
                              : role == 'manager'
                                  ? Colors.orange.withOpacity(0.12)
                                  : Colors.green.withOpacity(0.12),
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

                  // Details list
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.4)),
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
                  const Text(
                    'Assigned shops',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  if (shops.isEmpty)
                    const Text('No shops assigned')
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: shops
                          .map((s) => Chip(
                                label: Text(s),
                                visualDensity: VisualDensity.compact,
                              ))
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
      MaterialPageRoute(
        builder: (_) => AddEmployeeAndAccessScreen(existingEmployee: emp),
      ),
    );
  }

  Future<void> _confirmDelete(String uid, String name) async {
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
      await app.deleteEmployeeById(uid, name); // provider handles sync
      // Optional snackbar — agar off rakhna chaho toh comment kar do
      // if (mounted) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     const SnackBar(content: Text('Employee deleted')),
      //   );
      // }
    }
  }

  Widget _shopPreviewChips(List<String> shops) {
    if (shops.isEmpty) return const Text('No shops assigned');
    final visible = shops.take(2).toList();
    final remaining = shops.length - visible.length;

    return Row(
      children: [
        ...visible.map(
          (s) => Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Chip(label: Text(s), visualDensity: VisualDensity.compact),
          ),
        ),
        if (remaining > 0)
          PopupMenuButton<String>(
            tooltip: 'More shops',
            itemBuilder: (ctx) => shops
                .skip(2)
                .map((s) => PopupMenuItem<String>(value: s, child: Text(s)))
                .toList(),
            child: Chip(
              label: Text('+$remaining'),
              visualDensity: VisualDensity.compact,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppDataProvider>(context);
    final me = app.loggedInUser;
    final canManage = _canManage(me);

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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEmployeeAndAccessScreen()),
          );
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Add employee'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                int columns = 1;
                if (constraints.maxWidth >= 900) {
                  columns = 3;
                } else if (constraints.maxWidth >= 600) {
                  columns = 2;
                }

                final items = app.employees;
                if (items.isEmpty) {
                  return const Center(child: Text('No employees found'));
                }

                if (columns == 1) {
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _EmpCard(
                      emp: items[i],
                      canManage: canManage,
                      onAssign: (uid, name) =>
                          _openAssignShopsSheet(context, uid: uid, name: name),
                      onTap: () => _openEmployeeDetail(context, emp: items[i]),
                      onEdit: () => _editEmployee(items[i]),
                      onDelete: () {
                        final uid = (items[i]['uid'] ?? '').toString();
                        final name = (items[i]['name'] ?? '').toString();
                        if (uid.isNotEmpty) _confirmDelete(uid, name);
                      },
                      shopPreviewBuilder: _shopPreviewChips,
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 3.0,
                  ),
                  itemBuilder: (_, i) => _EmpCard(
                    emp: items[i],
                    canManage: canManage,
                    onAssign: (uid, name) =>
                        _openAssignShopsSheet(context, uid: uid, name: name),
                    onTap: () => _openEmployeeDetail(context, emp: items[i]),
                    onEdit: () => _editEmployee(items[i]),
                    onDelete: () {
                      final uid = (items[i]['uid'] ?? '').toString();
                      final name = (items[i]['name'] ?? '').toString();
                      if (uid.isNotEmpty) _confirmDelete(uid, name);
                    },
                    shopPreviewBuilder: _shopPreviewChips,
                  ),
                );
              },
            ),
    );
  }
}

class _EmpCard extends StatelessWidget {
  final Map<String, dynamic> emp;
  final bool canManage;
  final void Function(String uid, String name) onAssign;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Widget Function(List<String>) shopPreviewBuilder;

  const _EmpCard({
    required this.emp,
    required this.canManage,
    required this.onAssign,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.shopPreviewBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final name = (emp['name'] ?? '').toString();
    final role = (emp['role'] ?? '').toString().toLowerCase();
    final uid = (emp['uid'] ?? '').toString();
    final shops = (emp['assignedShops'] as List? ?? [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const CircleAvatar(child: Icon(Icons.person)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name.isEmpty ? 'Unnamed' : name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: role == 'admin'
                                ? Colors.indigo.withOpacity(0.12)
                                : role == 'manager'
                                    ? Colors.orange.withOpacity(0.12)
                                    : Colors.green.withOpacity(0.12),
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
                        if (canManage)
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                onEdit();
                              } else if (value == 'delete') {
                                onDelete();
                              } else if (value == 'assign') {
                                if (uid.isNotEmpty) onAssign(uid, name);
                              } else if (value == 'view') {
                                onTap();
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(value: 'view', child: Text('View info')),
                              const PopupMenuItem(value: 'edit', child: Text('Edit')),
                              const PopupMenuItem(value: 'assign', child: Text('Assign shops')),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    shopPreviewBuilder(shops),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (canManage)
                OutlinedButton(
                  onPressed: uid.isEmpty ? null : () => onAssign(uid, name),
                  child: const Text('Assign shops'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
