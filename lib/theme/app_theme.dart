import 'package:flutter/material.dart';
import 'package:meshiji/theme/tokens/design_tokens.dart';

class AppTheme {
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    fontFamily: 'Rosemary',

    // Core Colors & Transparency
    // This is the critical change to allow the BackdropFilter to work.
    canvasColor: Colors.transparent,
    scaffoldBackgroundColor: Colors.transparent,
    primaryColor: DesignTokens.accentPrimary,
    colorScheme: const ColorScheme.dark(
      primary: DesignTokens.accentPrimary,
      secondary: DesignTokens.accentPrimary, // Ensure background is transparent
      surface: DesignTokens.surfacePrimary,
      error: DesignTokens.accentDanger,
      onPrimary: DesignTokens.backgroundPrimary,
      onSecondary: DesignTokens.backgroundPrimary,
      onSurface: DesignTokens.textPrimary,
      onError: DesignTokens.textPrimary,
    ),

    // Typography
    textTheme: const TextTheme(
      bodyLarge: TextStyle(
        color: DesignTokens.textPrimary,
        fontFamily: 'Rosemary',
      ),
      bodyMedium: TextStyle(
        color: DesignTokens.textSecondary,
        fontFamily: 'Rosemary',
      ),
      titleLarge: TextStyle(
        color: DesignTokens.textPrimary,
        fontWeight: FontWeight.bold,
        fontFamily: 'Rosemary',
      ),
      titleMedium: TextStyle(
        color: DesignTokens.textPrimary,
        fontFamily: 'Rosemary',
      ),
      headlineSmall: TextStyle(
        color: DesignTokens.textPrimary,
        fontWeight: FontWeight.bold,
        fontFamily: 'Rosemary',
      ),
      labelLarge: TextStyle(
        color: DesignTokens.accentPrimary,
        fontFamily: 'Rosemary',
      ),
    ),

    // Component Themes
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: DesignTokens.accentPrimary),
      titleTextStyle: TextStyle(
        fontFamily: 'Rosemary',
        color: DesignTokens.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),

    listTileTheme: ListTileThemeData(
      iconColor: DesignTokens.accentPrimary,
      selectedColor: DesignTokens.selectionOverlay,
      selectedTileColor: DesignTokens.selectionOverlay.withValues(alpha: 0.1),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: DesignTokens.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusBase * 2),
      ),
    ),
  );
}
