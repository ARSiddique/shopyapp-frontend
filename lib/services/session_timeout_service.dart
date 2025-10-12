import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AutoLogoutSettings {
  final bool manualOnly;           // Manual => no auto logout
  final int activeIdleMinutes;     // Foreground idle
  final int inactiveMinutes;       // Background/paused

  const AutoLogoutSettings({
    required this.manualOnly,
    required this.activeIdleMinutes,
    required this.inactiveMinutes,
  });

  AutoLogoutSettings copyWith({
    bool? manualOnly,
    int? activeIdleMinutes,
    int? inactiveMinutes,
  }) {
    return AutoLogoutSettings(
      manualOnly: manualOnly ?? this.manualOnly,
      activeIdleMinutes: activeIdleMinutes ?? this.activeIdleMinutes,
      inactiveMinutes: inactiveMinutes ?? this.inactiveMinutes,
    );
  }

  @override
  String toString() =>
      'AutoLogoutSettings(manualOnly=$manualOnly, active=$activeIdleMinutes, inactive=$inactiveMinutes)';
}

class SessionTimeoutService with ChangeNotifier, WidgetsBindingObserver {
  static const _kManualOnly   = 'auto_logout_manual_only';
  static const _kActiveIdle   = 'auto_logout_active_idle_minutes';
  static const _kInactiveIdle = 'auto_logout_inactive_minutes';

  AutoLogoutSettings _settings = const AutoLogoutSettings(
    manualOnly: true,
    activeIdleMinutes: 15,
    inactiveMinutes: 10,
  );
  AutoLogoutSettings get settings => _settings;

  DateTime _lastInteraction = DateTime.now();
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;
  Timer? _tick;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    _settings = AutoLogoutSettings(
      manualOnly: sp.getBool(_kManualOnly) ?? true,
      activeIdleMinutes: sp.getInt(_kActiveIdle) ?? 15,
      inactiveMinutes: sp.getInt(_kInactiveIdle) ?? 10,
    );
    dev.log('Loaded $_settings', name: 'AUTOLOGOUT');
    notifyListeners();
  }

  Future<void> save(AutoLogoutSettings s) async {
    _settings = s;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kManualOnly, s.manualOnly);
    await sp.setInt(_kActiveIdle, s.activeIdleMinutes);
    await sp.setInt(_kInactiveIdle, s.inactiveMinutes);
    dev.log('Saved $_settings', name: 'AUTOLOGOUT');
    notifyListeners();
  }

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _lastInteraction = DateTime.now();
    _tick?.cancel();
    // fast checks so 1-minute test feel snappy (every 2s)
    _tick = Timer.periodic(const Duration(seconds: 2), (_) => _check());
    dev.log('Service started', name: 'AUTOLOGOUT');
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _tick = null;
    dev.log('Service stopped', name: 'AUTOLOGOUT');
  }

  void markInteraction() {
    _lastInteraction = DateTime.now();
    dev.log('Interaction', name: 'AUTOLOGOUT');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    if (state == AppLifecycleState.resumed) {
      _lastInteraction = DateTime.now(); // avoid instant logout on resume
    }
    dev.log('Lifecycle: $state', name: 'AUTOLOGOUT');
  }

  void _check() {
    if (_settings.manualOnly) return;

    final now = DateTime.now();
    final since = now.difference(_lastInteraction);
    dev.log('Tick: state=$_lifecycle, idle=${since.inSeconds}s', name: 'AUTOLOGOUT');

    if (_lifecycle == AppLifecycleState.resumed) {
      if (since.inMinutes >= _settings.activeIdleMinutes) _forceLogout();
    } else {
      if (since.inMinutes >= _settings.inactiveMinutes) _forceLogout();
    }
  }

  void _forceLogout() {
    dev.log('FORCE LOGOUT', name: 'AUTOLOGOUT');
    _tick?.cancel();
    _onLogout?.call();
  }

  // set by main.dart
  VoidCallback? _onLogout;
  void setOnLogoutRequested(VoidCallback cb) => _onLogout = cb;
}
