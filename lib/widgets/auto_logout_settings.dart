import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/session_timeout_service.dart';

class AutoLogoutSettingsCard extends StatefulWidget {
  const AutoLogoutSettingsCard({super.key});

  @override
  State<AutoLogoutSettingsCard> createState() => _AutoLogoutSettingsCardState();
}

class _AutoLogoutSettingsCardState extends State<AutoLogoutSettingsCard> {
  late bool manualOnly;
  late int activeIdle;
  late int inactive;

  @override
  void initState() {
    super.initState();
    final s = context.read<SessionTimeoutService>().settings;
    manualOnly = s.manualOnly;
    activeIdle = s.activeIdleMinutes;
    inactive = s.inactiveMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<SessionTimeoutService>();
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: cs.surface.withOpacity(0.7),
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Auto Logout Settings', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Manual'),
                  selected: manualOnly,
                  onSelected: (_) => setState(() => manualOnly = true),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Auto'),
                  selected: !manualOnly,
                  onSelected: (_) => setState(() => manualOnly = false),
                ),
              ],
            ),
            if (!manualOnly) ...[
              const SizedBox(height: 16),
              _NumberField(
                label: 'Active (Foreground) Idle Timeout (min)',
                initial: activeIdle, min: 1, max: 240,
                onChanged: (v) => activeIdle = v,
              ),
              const SizedBox(height: 12),
              _NumberField(
                label: 'Inactive (Background) Timeout (min)',
                initial: inactive, min: 1, max: 720,
                onChanged: (v) => inactive = v,
              ),
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('Save'),
                onPressed: () async {
                  await svc.save(
                    svc.settings.copyWith(
                      manualOnly: manualOnly,
                      activeIdleMinutes: activeIdle,
                      inactiveMinutes: inactive,
                    ),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Auto-logout settings saved')),
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

class _NumberField extends StatefulWidget {
  final String label;
  final int initial;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  const _NumberField({
    required this.label,
    required this.initial,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late TextEditingController _c;
  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.initial.toString());
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: '${widget.min}–${widget.max} minutes',
        border: const OutlineInputBorder(),
      ),
      onChanged: (v) {
        final n = int.tryParse(v) ?? widget.initial;
        widget.onChanged(n.clamp(widget.min, widget.max));
      },
    );
  }
}
