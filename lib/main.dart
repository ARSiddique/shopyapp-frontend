import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'providers/app_data_provider.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // US date symbols (for en_US formatting everywhere)
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
        ChangeNotifierProvider(
          create: (_) => AppDataProvider()
            ..restoreSession()
            ..startFirebaseListeners(), // live sync on
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
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
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'Shopy App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeProvider.themeMode,
      scrollBehavior: _AppScrollBehavior(),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        // Lock global text scaling so layout stable rahe
        final clamped = media.copyWith(textScaler: const TextScaler.linear(1.0));
        return MediaQuery(data: clamped, child: child ?? const SizedBox());
      },
      // App boot → Splash; Splash/AppDataProvider khud decide karega aage ka route
      home: const SplashScreen(),
    );
  }
}
