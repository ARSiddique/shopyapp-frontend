// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'providers/app_data_provider.dart';
import 'providers/theme_provider.dart';     // <-- add this
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('en_US');

  try {
    await Firebase.initializeApp();
  } catch (e, st) {
    // ignore: avoid_print
    print('🔥 Firebase init failed: $e\n$st');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),     // <-- add
        ChangeNotifierProvider(
          create: (_) => AppDataProvider()
            ..restoreSession()
            ..startFirebaseListeners(),
        ),
      ],
      child: const MyApp(),
    ),
  );
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
    final theme = context.watch<ThemeProvider>(); // <-- read provider

    return MaterialApp(
      title: 'Shopy App',
      debugShowCheckedModeBanner: false,

      // ✅ Wire themes to ThemeProvider (make sure AppTheme has both)
      theme: AppTheme.light,            // light theme
      darkTheme: AppTheme.dark,         // dark theme
      themeMode: theme.isDarkMode ? ThemeMode.dark : ThemeMode.light,

      scrollBehavior: _AppScrollBehavior(),

      builder: (context, child) {
        final media = MediaQuery.of(context);
        final clamped = media.copyWith(textScaler: const TextScaler.linear(1.0));
        return MediaQuery(data: clamped, child: child ?? const SizedBox());
      },

      home: const SplashScreen(),
    );
  }
}
