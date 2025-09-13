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

  // ---------------- Amount / Keypad ----------------
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
        return; // allow only one decimal point
      } else {
        _amount = '$_amount$d';
      }

      // clamp to 2 decimals
      final dot = _amount.indexOf('.');
      if (dot != -1 && _amount.length - dot - 1 > 2) {
        _amount = _amount.substring(0, dot + 3);
      }

      if (_amount.isEmpty) _amount = '0';
    });
  }

  void _clearAmount() => setState(() => _amount = '0');

  // ---------------- Draft ops ----------------
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
    if (_drafts.isNotEmpty) setState(() => _drafts.removeLast());
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

  // ---------------- Submit ----------------
  Future<void> _submit() async {
    if (_drafts.isEmpty || _submitting) return;

    final messenger = ScaffoldMessenger.of(context);
    final app = context.read<AppDataProvider>();

    // 🔒 Block adding if day already closed
    final now = DateTime.now();
    final closed = await app.isDayClosed(widget.shopName, now);
    if (closed) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Day is closed for this shop. Please post for next day.')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final creatorName = (app.loggedInUser?['name'] ?? user?.email ?? 'user').toString();
    final dayKey = app.dayKeyOf(now);

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
      if (!mounted) return;
      setState(() {
        _drafts.clear();
        _amount = '0';
        _refund = false;
      });
      messenger.showSnackBar(const SnackBar(content: Text('Transactions submitted')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final isWide = w >= 900;

    // Responsive scale
    final scale =
        w < 340 ? 0.80 : w < 380 ? 0.88 : w < 420 ? 0.95 : w < 600 ? 1.00 : w < 900 ? 1.08 : 1.15;
    final pad = 14.0 * scale.clamp(0.8, 1.0);

    return Scaffold(
      appBar: AppBar(title: Text('Transactions · ${widget.shopName}')),
      body: Padding(
        padding: EdgeInsets.all(pad),
        child: LayoutBuilder(
          builder: (c, cons) {
            if (isWide) {
              // Two-pane: left list is scrollable independently; right keypad never moves
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SizedBox(
                      height: cons.maxHeight,
                      child: _leftPanel(context, scale: scale, boundedHeight: true),
                    ),
                  ),
                  SizedBox(width: pad),
                  SizedBox(width: 340, child: _rightPanel(scale)),
                ],
              );
            } else {
              // Single column — keypad fixed at bottom via SafeArea + IntrinsicHeight
              return Column(
                children: [
                  Expanded(child: _leftPanel(context, scale: scale, boundedHeight: true)),
                  const SizedBox(height: 8),
                  _rightPanel(scale),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  Widget _leftPanel(BuildContext context, {required double scale, required bool boundedHeight}) {
    final titleFs = (26.0 * scale).clamp(18.0, 32.0);
    final smallFs = (12.0 * scale).clamp(11.0, 14.0);
    final gap = 10.0 * scale.clamp(0.8, 1.0);

    final total = _sum();
    final cash = _sum(only: 'cash');
    final card = _sum(only: 'card');
    final other = _sum(only: 'other');

    final list = ListView.builder(
      shrinkWrap: !boundedHeight,
      physics: boundedHeight ? const AlwaysScrollableScrollPhysics() : const NeverScrollableScrollPhysics(),
      itemCount: _drafts.length,
      itemBuilder: (_, i) {
        final d = _drafts[i];
        final sign = d.refund ? '-' : '+';
        final methodLabel = d.method == 'cash' ? 'Cash' : d.method == 'card' ? 'Card' : 'Other';

        return Dismissible(
          key: ValueKey('draft_${i}_${d.amount}_${d.method}_${d.refund}'),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) => setState(() => _drafts.removeAt(i)),
          child: ListTile(
            dense: true,
            visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
            leading: Text(
              sign,
              style: TextStyle(
                color: d.refund ? Colors.red : Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: smallFs,
              ),
            ),
            title: Text('\$ ${d.amount.toStringAsFixed(2)}', style: TextStyle(fontSize: smallFs)),
            trailing: Text(methodLabel, style: TextStyle(fontSize: smallFs)),
            // Tap to edit this item
            onTap: () {
              setState(() {
                _amount = d.amount.toStringAsFixed(2);
                _method = d.method;
                _refund = d.refund;
                _drafts.removeAt(i);
              });
            },
          ),
        );
      },
    );

    return Card(
      child: Padding(
        padding: EdgeInsets.all(gap),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('\$ $_amount', style: TextStyle(fontSize: titleFs, fontWeight: FontWeight.bold)),
            SizedBox(height: gap * 0.7),
            Row(
              children: [
                Text('Added items', style: TextStyle(fontWeight: FontWeight.w600, fontSize: smallFs)),
                const Spacer(),
                TextButton(
                  onPressed: _remove,
                  style: TextButton.styleFrom(visualDensity: const VisualDensity(horizontal: -2, vertical: -2)),
                  child: Text('Remove Item', style: TextStyle(fontSize: smallFs)),
                ),
                TextButton(
                  onPressed: _clearAll,
                  style: TextButton.styleFrom(visualDensity: const VisualDensity(horizontal: -2, vertical: -2)),
                  child: Text('Clear All', style: TextStyle(fontSize: smallFs)),
                ),
              ],
            ),
            const Divider(height: 16),
            if (boundedHeight) Expanded(child: list) else list,
            const Divider(height: 16),
            Row(
              children: [
                Text('Cash: \$${cash.toStringAsFixed(2)}', style: TextStyle(fontSize: smallFs)),
                const Spacer(),
                Text('Card: \$${card.toStringAsFixed(2)}', style: TextStyle(fontSize: smallFs)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('Other: \$${other.toStringAsFixed(2)}', style: TextStyle(fontSize: smallFs)),
                const Spacer(),
                Text('Total: \$${total.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: smallFs)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _rightPanel(double scale) {
    const keys = ['1','2','3','4','5','6','7','8','9','.','0','<<'];

    final gap = 10.0 * scale.clamp(0.8, 1.0);
    final chipFs = (12.0 * scale).clamp(11.0, 13.5);
    final btnFs = (14.0 * scale).clamp(12.0, 16.0);
    final crossSpace = 6.0 * scale.clamp(0.8, 1.0);
    final mainSpace = 6.0 * scale.clamp(0.8, 1.0);
    final childAspect = 1.35; // slimmer keypad buttons
    final cellPadV = (8.0 * scale).clamp(6.0, 10.0);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(gap),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  label: Text('Cash', style: TextStyle(fontSize: chipFs)),
                  selected: _method == 'cash',
                  onSelected: (_) => setState(() => _method = 'cash'),
                ),
                ChoiceChip(
                  label: Text('Card', style: TextStyle(fontSize: chipFs)),
                  selected: _method == 'card',
                  onSelected: (_) => setState(() => _method = 'card'),
                ),
                ChoiceChip(
                  label: Text('Other', style: TextStyle(fontSize: chipFs)),
                  selected: _method == 'other',
                  onSelected: (_) => setState(() => _method = 'other'),
                ),
                FilterChip(
                  label: Text('Refund', style: TextStyle(fontSize: chipFs)),
                  selected: _refund,
                  onSelected: (_) => setState(() => _refund = !_refund),
                ),
              ],
            ),
            SizedBox(height: gap),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: keys.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: mainSpace,
                crossAxisSpacing: crossSpace,
                childAspectRatio: childAspect,
              ),
              itemBuilder: (_, i) {
                final t = keys[i];
                return ElevatedButton(
                  onPressed: () => _digit(t),
                  onLongPress: t == '0'
                      ? () => _digit('00')
                      : t == '<<'
                          ? _clearAmount
                          : null,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: cellPadV),
                    minimumSize: const Size(0, 34), // compact
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(t, style: TextStyle(fontSize: btnFs)),
                );
              },
            ),
            SizedBox(height: gap),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: (double.tryParse(_amount) ?? 0) > 0 ? _add : null,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: cellPadV),
                      minimumSize: const Size(0, 34),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Add', style: TextStyle(fontSize: btnFs)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: cellPadV),
                      minimumSize: const Size(0, 34),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(_submitting ? 'Submitting…' : 'Submit', style: TextStyle(fontSize: btnFs)),
                  ),
                ),
              ],
            ),
          ],
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
