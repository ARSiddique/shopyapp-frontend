// lib/main.dart
import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/app_data_provider.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'services/session_timeout_service.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

// Pref keys (Profile screen use the same)
const _kManualOnly   = 'auto_logout_manual_only';
const _kActiveIdle   = 'auto_logout_active_idle_minutes';
const _kInactiveIdle = 'auto_logout_inactive_minutes';

// DEFAULTS (when prefs not set)
const int kDefaultActiveMinutes   = 120;   // ✅ Active default = 5
const int kDefaultInactiveMinutes = 240;  // ✅ Inactive default = 10

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('en_US');
  try { await Firebase.initializeApp(); } catch (e, st) { print('🔥 Firebase init failed: $e\n$st'); }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (_) => AppDataProvider()
            ..restoreSession()
            ..startFirebaseListeners(),
        ),
        // so ProfileScreen's watch(...) never crashes
        ChangeNotifierProvider(create: (_) => SessionTimeoutService()),
      ],
      child: const MyApp(),
    ),
  );
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };
}

class _NavSpy extends NavigatorObserver {
  final VoidCallback onBump;
  _NavSpy(this.onBump);
  @override void didPush(Route route, Route? previousRoute) => onBump();
  @override void didReplace({Route? newRoute, Route? oldRoute}) => onBump();
  @override void didPop(Route route, Route? previousRoute) => onBump();
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override State<MyApp> createState() => _MyAppState();
}

/// Auto-logout by PURE DURATION:
/// - ACTIVE (foreground) => logout after N minutes (interaction irrelevant)
/// - INACTIVE (background/off) => logout after M minutes
class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  // runtime settings
  bool manualOnly = true;
  int activeMins = kDefaultActiveMinutes;
  int inactiveMins = kDefaultInactiveMinutes;

  // clocks
  Timer? _tick;
  DateTime _foregroundStart = DateTime.now();
  DateTime? _backgroundStart;
  AppLifecycleState _life = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resetActiveWindow();
    _startTicker();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    super.dispose();
  }

  // Logged-in or on Login/Splash?
  bool _isLoggedIn() {
    try {
      final app = context.read<AppDataProvider>();
      return app.loggedInUser != null; // adjust if you have a different flag
    } catch (_) {
      return false;
    }
  }

  void _startTicker() {
    _tick?.cancel();
    // keep tick running; checks pause themselves on Login/Splash
    _tick = Timer.periodic(const Duration(seconds: 2), (_) => _check());
  }

  void _resetActiveWindow() {
    _foregroundStart = DateTime.now();
    _backgroundStart = null;
  }

  Future<void> _loadSettings() async {
    final sp = await SharedPreferences.getInstance();
    manualOnly   = sp.getBool(_kManualOnly) ?? true; // default = Auto ON
    activeMins   = sp.getInt(_kActiveIdle) ?? kDefaultActiveMinutes;
    inactiveMins = sp.getInt(_kInactiveIdle) ?? kDefaultInactiveMinutes;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _life = state;
    if (state == AppLifecycleState.resumed) {
      _resetActiveWindow();
    } else {
      _backgroundStart ??= DateTime.now();
    }
  }

  Future<void> _check() async {
    // Pause auto-logout on Login/Splash
    if (!_isLoggedIn()) {
      _resetActiveWindow(); // never fires on login
      return;
    }

    await _loadSettings();
    if (manualOnly) return; // Manual mode => never auto-logout

    if (_life == AppLifecycleState.resumed) {
      final sec = DateTime.now().difference(_foregroundStart).inSeconds;
      if (sec >= activeMins * 60) _forceLogout();
    } else {
      final base = _backgroundStart ?? DateTime.now();
      final sec = DateTime.now().difference(base).inSeconds;
      if (sec >= inactiveMins * 60) _forceLogout();
    }
  }

  void _forceLogout() {
    try {
      final app = context.read<AppDataProvider>();
      app.logout();
    } catch (_) {}
    _resetActiveWindow();
    rootNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _onRouteBump() {
    _resetActiveWindow();
    if (_tick == null || !_tick!.isActive) _startTicker();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      navigatorObservers: [_NavSpy(_onRouteBump)],
      title: 'Shopy App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      scrollBehavior: _AppScrollBehavior(),
      // No debug overlay/ticking text anymore
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final clamped = media.copyWith(textScaler: const TextScaler.linear(1.0));
        return MediaQuery(data: clamped, child: child ?? const SizedBox());
      },
      home: const SplashScreen(),
    );
  }
}
