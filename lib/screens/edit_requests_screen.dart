import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

class EditRequestsScreen extends StatelessWidget {
  const EditRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();
    final isManager = app.isManager || app.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Requests'),
        backgroundColor: Colors.deepPurple,
      ),
      body: isManager ? _ManagerList() : _MyRequestsList(),
    );
  }
}

class _ManagerList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();

    // live list from provider listener
    final reqs = app.editRequests.toList()
      ..sort((a, b) {
        final at = (a['timestamp'] is DateTime)
            ? a['timestamp'] as DateTime
            : (a['timestamp'] is Timestamp)
                ? (a['timestamp'] as Timestamp).toDate()
                : DateTime(1970);
        final bt = (b['timestamp'] is DateTime)
            ? b['timestamp'] as DateTime
            : (b['timestamp'] is Timestamp)
                ? (b['timestamp'] as Timestamp).toDate()
                : DateTime(1970);
        return bt.compareTo(at);
      });

    if (reqs.isEmpty) {
      return const Center(child: Text('No edit requests'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: reqs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final r = reqs[i];
        final id = (r['firebaseId'] ?? '').toString();
        final type = (r['type'] ?? '').toString(); // 'order' | 'sale'
        final itemId = (r['itemId'] ?? '').toString();
        final reason = (r['reason'] ?? '').toString();
        final requestedBy = (r['requestedBy'] ?? '').toString();
        final status = (r['status'] ?? 'pending').toString();
        final newAmount = r['newAmount'];
        final tsRaw = r['timestamp'];
        final when = (tsRaw is Timestamp)
            ? tsRaw.toDate()
            : (tsRaw is DateTime)
                ? tsRaw
                : DateTime.now();

        return Card(
          child: ListTile(
            title: Text('${type.toUpperCase()} • Item: $itemId'),
            subtitle: Text(
              [
                if (newAmount != null) 'New amount: $newAmount',
                if (reason.isNotEmpty) 'Reason: $reason',
                'By: $requestedBy',
                'When: ${DateFormat('dd MMM, hh:mm a').format(when)}',
                'Status: ${status[0].toUpperCase()}${status.substring(1)}',
              ].join('\n'),
            ),
            isThreeLine: true,
            trailing: status == 'pending'
                ? Wrap(
                    spacing: 8,
                    children: [
                      IconButton(
                        tooltip: 'Approve',
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        onPressed: () async {
                          if (!ctx.mounted) return;
                          await ctx.read<AppDataProvider>().approveEditRequest(id);
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Request approved')),
                          );
                        },
                      ),
                      IconButton(
                        tooltip: 'Reject',
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        onPressed: () async {
                          if (!ctx.mounted) return;
                          await ctx.read<AppDataProvider>().rejectEditRequest(id);
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Request rejected')),
                          );
                        },
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}

class _MyRequestsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();
    final me = (app.loggedInUser?['name'] ?? '').toString();

    final reqs = app.editRequests
        .where((r) => (r['requestedBy'] ?? '') == me)
        .toList()
      ..sort((a, b) {
        final at = (a['timestamp'] is Timestamp)
            ? (a['timestamp'] as Timestamp).toDate()
            : (a['timestamp'] as DateTime? ?? DateTime(1970));
        final bt = (b['timestamp'] is Timestamp)
            ? (b['timestamp'] as Timestamp).toDate()
            : (b['timestamp'] as DateTime? ?? DateTime(1970));
        return bt.compareTo(at);
      });

    if (reqs.isEmpty) {
      return const Center(child: Text('You have no requests'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: reqs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final r = reqs[i];
        final type = (r['type'] ?? '').toString();
        final itemId = (r['itemId'] ?? '').toString();
        final status = (r['status'] ?? 'pending').toString();
        final reason = (r['reason'] ?? '').toString();

        return Card(
          child: ListTile(
            title: Text('${type.toUpperCase()} • Item: $itemId'),
            subtitle: Text('Reason: $reason\nStatus: $status'),
          ),
        );
      },
    );
  }
}
