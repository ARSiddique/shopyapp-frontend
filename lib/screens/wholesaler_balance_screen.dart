import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

class WholesalerBalanceScreen extends StatefulWidget {
  final String wholesalerName;
  const WholesalerBalanceScreen({super.key, required this.wholesalerName});

  @override
  State<WholesalerBalanceScreen> createState() => _WholesalerBalanceScreenState();
}

class _WholesalerBalanceScreenState extends State<WholesalerBalanceScreen> {
  final Map<String, TextEditingController> _prevCtrls = {};
  final Map<String, TextEditingController> _newCtrls = {};
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() {
    for (final c in _prevCtrls.values) { c.dispose(); }
    for (final c in _newCtrls.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final app = context.read<AppDataProvider>();
    final shops = app.shops.map((e) => (e['name'] ?? '').toString()).toList();
    for (final s in shops) {
      final b = await app.getWholesalerShopBalance(
        shopName: s, wholesalerName: widget.wholesalerName,
      );
      _prevCtrls[s] = TextEditingController(text: b.toStringAsFixed(2));
      _newCtrls[s]  = TextEditingController(text: b.toStringAsFixed(2));
    }
    setState(() => _loading = false);
  }

  Future<void> _update() async {
    final app = context.read<AppDataProvider>();
    for (final entry in _newCtrls.entries) {
      final shop = entry.key;
      final newBal = double.tryParse(entry.value.text) ?? 0.0;
      await app.setWholesalerShopBalance(
        shopName: shop,
        wholesalerName: widget.wholesalerName,
        newBalance: newBal,
      );
      _prevCtrls[shop]?.text = newBal.toStringAsFixed(2);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Balances updated')));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppDataProvider>();
    final theme = Theme.of(context);
    final shops = app.shops.map((e) => (e['name'] ?? '').toString()).toList();

    return _loading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    Expanded(child: Text('Previous Balance (editable)', style: theme.textTheme.titleMedium)),
                    const SizedBox(width: 12),
                    Expanded(child: Text('New Balance', textAlign: TextAlign.right, style: theme.textTheme.titleMedium)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: shops.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    if (i == shops.length) {
                      return Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: _update,
                          icon: const Icon(Icons.save_rounded),
                          label: const Text('Update'),
                        ),
                      );
                    }
                    final s = shops[i];
                    return Row(
                      children: [
                        Expanded(
                          flex: 28,
                          child: _box(theme, child: Text(s, style: theme.textTheme.bodyMedium)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 24,
                          child: _box(theme, child: TextField(
                            controller: _prevCtrls[s],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.all(0)),
                          )),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 24,
                          child: _box(theme, child: TextField(
                            controller: _newCtrls[s],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.all(0)),
                            textAlign: TextAlign.right,
                          )),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
  }

  Widget _box(ThemeData theme, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: .25)),
        color: theme.colorScheme.surface,
      ),
      child: child,
    );
  }
}
