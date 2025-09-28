// lib/screens/wholesalers_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_data_provider.dart';
import 'wholesaler_drilldown_screen.dart';
import 'wholesaler_invoices_screen.dart';

class WholesalersListScreen extends StatefulWidget {
  const WholesalersListScreen({
    super.key,
    this.selectMode = false,
    this.openInvoicesDirect = false, // 👈 NEW: open invoices tab directly
  });

  /// selectMode = true ⇒ tap returns wholesaler name via Navigator.pop
  final bool selectMode;

  /// when true ⇒ tapping a wholesaler opens WholesalerInvoicesScreen immediately
  final bool openInvoicesDirect;

  @override
  State<WholesalersListScreen> createState() => _WholesalersListScreenState();
}

class _WholesalersListScreenState extends State<WholesalersListScreen> {
  bool _loading = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    final app = context.read<AppDataProvider>();
    // pehli dafa list refresh
    Future.microtask(() => _refresh(app));
  }

  Future<void> _refresh(AppDataProvider app) async {
    setState(() => _loading = true);
    try {
      await app.fetchWholesalers();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addWholesalerDialog(AppDataProvider app) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final noteCtrl  = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Wholesaler'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl,  decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone (optional)')),
              TextField(controller: noteCtrl,  decoration: const InputDecoration(labelText: 'Address/Note (optional)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );

    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      final err = await app.addOrUpdateWholesaler(
        name: nameCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        address: noteCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err == null ? 'Wholesaler added' : 'Failed: $err')),
      );
      await _refresh(app);
    }
  }

  void _openDrilldown(String name) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WholesalerDrilldownScreen(initialQuery: name)),
    );
  }

  void _openInvoices(String name) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WholesalerInvoicesScreen(wholesalerName: name)),
    );
  }

  Future<void> _confirmDelete(AppDataProvider app, String name) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete wholesaler?'),
        content: Text('This will remove “$name”. Orders will remain. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (sure == true) {
      await app.deleteWholesalerByName(name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted $name')));
      await _refresh(app);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();

    final items = app.wholesalers
        .where((w) =>
            _query.isEmpty ||
            (w['name'] ?? '')
                .toString()
                .toLowerCase()
                .contains(_query.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wholesalers'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : () => _refresh(app),
            icon: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search wholesaler…',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addWholesalerDialog(app),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add'),
      ),

      body: items.isEmpty
          ? const Center(child: Text('No wholesalers found'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final w = items[i];
                final name = (w['name'] ?? '').toString();
                final phone = (w['phone'] ?? '').toString();
                final subtitle = phone.isEmpty ? (w['address'] ?? '').toString() : phone;

                return Card(
                  elevation: 0.6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      if (widget.openInvoicesDirect) {
                        // 👉 Invoices flow (coming from AllShopsHub “Wholesaler Invoices” card)
                        _openInvoices(name);
                      } else if (widget.selectMode) {
                        // picker flow
                        Navigator.pop(context, name);
                      } else {
                        // default flow → drilldown
                        _openDrilldown(name);
                      }
                    },
                    onLongPress: widget.openInvoicesDirect
                        ? null // invoices-direct me long press menu nahi
                        : () async {
                            // context menu: choose where to go
                            final RenderBox box = context.findRenderObject()! as RenderBox;
                            final offset = box.localToGlobal(Offset.zero);
                            final choice = await showMenu<String>(
                              context: context,
                              position: RelativeRect.fromLTRB(
                                offset.dx + 180, offset.dy + 140, 16, 0),
                              items: const [
                                PopupMenuItem(value: 'invoices', child: Text('Invoices / Payments / Balance')),
                                PopupMenuItem(value: 'drill',    child: Text('Open Drilldown')),
                              ],
                            );
                            if (choice == 'invoices') _openInvoices(name);
                            if (choice == 'drill') _openDrilldown(name);
                          },
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      leading: const CircleAvatar(child: Icon(Icons.store_rounded)),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: subtitle.isEmpty ? null : Text(subtitle),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!widget.openInvoicesDirect && !widget.selectMode)
                            IconButton(
                              tooltip: 'More',
                              icon: const Icon(Icons.more_vert),
                              onPressed: () async {
                                final choice = await showMenu<String>(
                                  context: context,
                                  position: const RelativeRect.fromLTRB(1000, 80, 12, 0),
                                  items: const [
                                    PopupMenuItem(value: 'invoices', child: Text('Invoices / Payments / Balance')),
                                    PopupMenuItem(value: 'drill',    child: Text('Open Drilldown')),
                                  ],
                                );
                                if (choice == 'invoices') _openInvoices(name);
                                if (choice == 'drill') _openDrilldown(name);
                              },
                            ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _confirmDelete(app, name),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
