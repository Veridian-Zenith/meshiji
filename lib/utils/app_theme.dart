import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryRed = Color(0xFFB71C1C);
  static const Color accentRed = Color(0xFFE53935);
  static const Color backgroundBlack = Color(0xFF000000);
  static const Color glassBlack = Color(0xCC050505);

  static ThemeData get theme {
    return ThemeData(
      colorScheme: const ColorScheme.dark(
        primary: primaryRed,
        secondary: accentRed,
        surface: backgroundBlack,
        onSurface: Colors.white,
      ),
      useMaterial3: true,
      fontFamily: 'Delius',
      scaffoldBackgroundColor: backgroundBlack,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: primaryRed,
          fontSize: 28,
          fontWeight: FontWeight.w900,
          letterSpacing: 8,
          shadows: [Shadow(color: primaryRed, blurRadius: 10)],
        ),
      ),
      cardTheme: CardThemeData(
        color: glassBlack,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: primaryRed.withOpacity(0.3), width: 1),
        ),
      ),
      listTileTheme: ListTileThemeData(
        textColor: Colors.white70,
        iconColor: primaryRed,
        selectedColor: Colors.white,
        selectedTileColor: primaryRed.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF0A0A0A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: primaryRed, width: 1),
        ),
      ),
    );
  }
}
