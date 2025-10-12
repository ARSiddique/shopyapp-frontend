import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/session_timeout_service.dart';

class SessionActivityTracker extends StatelessWidget {
  final Widget child;
  const SessionActivityTracker({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final svc = context.read<SessionTimeoutService>();
    return Listener(
      onPointerDown: (_) => svc.markInteraction(),
      onPointerMove: (_) => svc.markInteraction(),
      onPointerUp:   (_) => svc.markInteraction(),
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, __) {
          svc.markInteraction();
          return KeyEventResult.ignored;
        },
        child: child,
      ),
    );
  }
}
