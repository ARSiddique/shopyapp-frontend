// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter/gestures.dart'; // <- add this
import 'providers/app_data_provider.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase init (show a meaningful error in logs, avoid silent crash)
  await runZonedGuarded(() async {
    await Firebase.initializeApp();

    runApp(
      MultiProvider(
        providers: [
          // AppDataProvider boot + session restore (SharedPrefs / FirebaseAuth)
          ChangeNotifierProvider(
            create: (_) => AppDataProvider()..restoreSession(),
          ),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: const MyApp(),
      ),
    );
  }, (error, stack) {
    // You can hook Crashlytics etc. here if needed
    debugPrint('🔥 Uncaught error: $error');
  });
}

/// Desktop/Web friendly scroll behavior (mouse, touch, trackpad, stylus)
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'Shopy App',
      debugShowCheckedModeBanner: false,

      // 🔷 Hi-tech theme (from your AppTheme)
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeProvider.themeMode,

      // 🔁 Smooth scrolling on desktop/web too
      scrollBehavior: _AppScrollBehavior(),

      // 🅰️ Clamp text scaling so LED/desktop par bhi UI balanced rahe
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final clamped = media.copyWith(
          textScaler: const TextScaler.linear(1.0), // lock to designer scale
        );
        return MediaQuery(data: clamped, child: child ?? const SizedBox());
      },

      // First screen → Splash (yahi se restoreSession result ke hisaab se route hoti)
      home: const SplashScreen(),
    );
  }
}
