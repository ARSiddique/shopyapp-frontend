import 'package:flutter/material.dart';

/// Single-theme provider: app is always in Dark Mode.
/// We keep the class so the rest of your code compiles unchanged.
class ThemeProvider extends ChangeNotifier {
  ThemeMode get themeMode => ThemeMode.dark;
  bool get isDarkMode => true;

  /// No-op: we ignore any attempts to toggle the theme.
  Future<void> toggleTheme(bool isOn) async {
    // intentionally do nothing
  }
}
