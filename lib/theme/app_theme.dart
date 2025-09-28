// lib/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get darkOnly {
    const bg = Color(0xFF0A111B);
    const panel = Color(0xFF121A26);
    const header = Color(0xFF0F1522);
    const mint = Color(0xFF2AF4C9);
    const green = Color(0xFF22C55E);

    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: bg,
      canvasColor: bg,

      colorScheme: base.colorScheme.copyWith(
        primary: green,
        secondary: mint,
        surface: panel,
        onSurface: Colors.white,
        onPrimary: Colors.black,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: header,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      cardColor: panel,

      // ✅ FIX: use DialogThemeData (not DialogTheme)
      dialogTheme: const DialogThemeData(
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),

      chipTheme: base.chipTheme.copyWith(
        backgroundColor: const Color(0xFF1A2433),
        side: const BorderSide(color: Colors.white12),
        labelStyle: const TextStyle(color: Colors.white),
      ),

      dataTableTheme: const DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(Color(0xFF1A2433)),
        headingTextStyle:
            TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        dataTextStyle: TextStyle(color: Colors.white70),
        dividerThickness: 0.8,
      ),

      dividerTheme: const DividerThemeData(
        color: Colors.white24,
        thickness: 0.8,
        space: 1,
      ),

      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFF101826),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFF6EE7B7)),
        ),
        labelStyle: TextStyle(color: Colors.white70),
        hintStyle: TextStyle(color: Colors.white38),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: green,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF334155),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: mint,
        foregroundColor: Colors.black,
        shape: StadiumBorder(),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF1A2433),
        contentTextStyle: TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: Colors.white70,
        textColor: Colors.white,
      ),
      iconTheme: const IconThemeData(color: Colors.white70),
      textTheme: base.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
    );
  }
}
