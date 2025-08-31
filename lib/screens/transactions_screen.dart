// lib/screens/transactions_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_data_provider.dart';

class TransactionsScreen extends StatefulWidget {
  final String shopName;
  const TransactionsScreen({super.key, required this.shopName});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _amount = '0';
  String _method = 'cash'; // cash | card | other
  bool _refund = false;
  bool _submitting = false;

  final List<_Draft> _drafts = [];

  // ---------- Input helpers ----------
  void _digit(String d) {
    setState(() {
      if (d == '<<') {
        _amount = _amount.length <= 1 ? '0' : _amount.substring(0, _amount.length - 1);
        return;
      }
      if (_amount == '0' && d != '.' && d != '00') {
        _amount = d;
      } else if (d == '00') {
        _amount = _amount == '0' ? '0' : '${_amount}00';
      } else if (d == '.' && _amount.contains('.')) {
        return; // single decimal point
      } else {
        _amount = '$_amount$d';
      }

      // clamp to 2 decimals
      final dot = _amount.indexOf('.');
      if (dot != -1 && _amount.length - dot - 1 > 2) {
        _amount = _amount.substring(0, dot + 3);
      }
    });
  }

  void _add() {
    final v = double.tryParse(_amount) ?? 0;
    if (v <= 0) return;
    setState(() {
      _drafts.add(_Draft(v, _method, _refund));
      _amount = '0';
      _refund = false;
    });
  }

  void _remove() {
    if (_drafts.isNotEmpty) {
      setState(() => _drafts.removeLast());
    }
  }

  void _clearAll() {
    if (_drafts.isNotEmpty) {
      setState(() {
        _drafts.clear();
        _amount = '0';
        _refund = false;
      });
    }
  }

  double _sum({String? only}) {
    double s = 0;
    for (final d in _drafts) {
      if (only != null && d.method != only) continue;
      s += d.refund ? -d.amount : d.amount;
    }
    return s;
  }

  // ---------- Submit to Firestore ----------
  Future<void> _submit() async {
    if (_drafts.isEmpty || _submitting) return;

    final ctx = context;
    final messenger = ScaffoldMessenger.of(ctx);
    final app = ctx.read<AppDataProvider>();

    final user = FirebaseAuth.instance.currentUser;
    final creatorName = (app.loggedInUser?['name'] ?? user?.email ?? 'user').toString();

    final dayKey = app.dayKeyOf(DateTime.now());

    final rows = _drafts.map((d) {
      final signed = d.refund ? -d.amount : d.amount;
      return {
        'shopName': widget.shopName,
        'amount': double.parse(signed.toStringAsFixed(2)),
        'method': d.method,           // 'cash' | 'card' | 'other'
        'isRefund': d.refund,
        'createdAt': Timestamp.now(),
        'dayKey': dayKey,
        'createdByUid': user?.uid,
        'createdByName': creatorName,
      };
    }).toList();

    setState(() => _submitting = true);
    try {
      await app.addTransactionBatch(rows);
      if (!mounted || !ctx.mounted) return;

      setState(() {
        _drafts.clear();
        _amount = '0';
        _refund = false;
      });

      messenger.showSnackBar(
        const SnackBar(content: Text('Transactions submitted')),
      );
    } catch (e) {
      if (!mounted || !ctx.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final total = _sum();
    final cash = _sum(only: 'cash');
    final card = _sum(only: 'card');
    final other = _sum(only: 'other');

    // Flat keypad list (3 columns). Last item includes '.'
   const keypad = ['1','2','3','4','5','6','7','8','9','.','0','<<'];

    return Scaffold(
      appBar: AppBar(title: Text('Transaction · ${widget.shopName}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (c, cons) {
            final wide = cons.maxWidth >= 900;

            // LEFT: items + totals
            final left = Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      '\$ $_amount',
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Added items', style: TextStyle(fontWeight: FontWeight.w600)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _remove,
                          icon: const Icon(Icons.remove_circle_outline),
                          label: const Text('Remove last'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: _clearAll,
                          icon: const Icon(Icons.clear_all),
                          label: const Text('Clear all'),
                        ),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _drafts.length,
                        itemBuilder: (_, i) {
                          final d = _drafts[i];
                          final sign = d.refund ? '-' : '+';
                          final m = d.method == 'cash'
                              ? 'Cash'
                              : d.method == 'card'
                                  ? 'Card'
                                  : 'Other';
                          return ListTile(
                            dense: true,
                            leading: Text(
                              sign,
                              style: TextStyle(
                                color: d.refund
                                    ? Colors.red
                                    : Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            title: Text('\$ ${d.amount.toStringAsFixed(2)}'),
                            trailing: Text(m),
                          );
                        },
                      ),
                    ),
                    const Divider(),
                    Column(
                      children: [
                        Row(
                          children: [
                            Text('Cash: \$${cash.toStringAsFixed(2)}'),
                            const Spacer(),
                            Text('Card: \$${card.toStringAsFixed(2)}'),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text('Other: \$${other.toStringAsFixed(2)}'),
                            const Spacer(),
                            Text(
                              'Total: \$${total.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );

            // RIGHT: keypad + chips + actions
            Widget rightPanel() {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Cash'),
                            selected: _method == 'cash',
                            onSelected: (_) => setState(() => _method = 'cash'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Card'),
                            selected: _method == 'card',
                            onSelected: (_) => setState(() => _method = 'card'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Other'),
                            selected: _method == 'other',
                            onSelected: (_) => setState(() => _method = 'other'),
                          ),
                          const Spacer(),
                          FilterChip(
                            label: const Text('Refund'),
                            selected: _refund,
                            onSelected: (_) => setState(() => _refund = !_refund),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: keypad.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemBuilder: (_, i) {
                          final t = keypad[i];
                          return ElevatedButton(
                            onPressed: () => _digit(t),
                            // Tip: long-press 0 => add '00'
                            onLongPress: t == '0' ? () => _digit('00') : null,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Text(t, style: const TextStyle(fontSize: 18)),
                            ),
                         );
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: (double.tryParse(_amount) ?? 0) > 0 ? _add : null,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                child: Text('Add'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _submitting ? null : _submit,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                child: Text(_submitting ? 'Submitting…' : 'Submit'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }

            return wide
                ? Row(
                    children: [
                      Expanded(child: left),
                      const SizedBox(width: 16),
                      SizedBox(width: 420, child: rightPanel()),
                    ],
                  )
                : Column(
                    children: [
                      left,
                      const SizedBox(height: 16),
                      rightPanel(),
                    ],
                  );
          },
        ),
      ),
    );
  }
}

class _Draft {
  final double amount;
  final String method;
  final bool refund;
  _Draft(this.amount, this.method, this.refund);
}
