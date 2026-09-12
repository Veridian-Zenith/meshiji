import 'package:flutter/material.dart';

// AMOLED red/black — keeps floating runes, rounded tokens
class DesignTokens {
  static const Color colorBlack = Color(0xFF050505); // pure AMOLED black
  static const Color colorRed = Color(0xFFE50914);   // Netflix-style red
  static const Color colorDarkRed = Color(0xFF8B1515);
  static const Color colorWhite = Color(0xFFFFFFFF);
  static const Color colorMuted = Color(0xFFAAAAAA);
  static const Color colorGrey = Color(0xFF333333);

  static const double spacingBase = 8.0;
  static const double radiusBase = 16.0; // more rounded
  static const Duration durationFast = Duration(milliseconds: 120);
  static const Duration durationStandard = Duration(milliseconds: 200);
  static const Duration durationEmphasis = Duration(milliseconds: 320);

  static const Color backgroundPrimary = Color(0xFF000000);
  static const Color backgroundSecondary = Color(0xFF0A0A0A);
  static const Color surfacePrimary = Color(0xFF0F0F0F);
  static const Color surfaceElevated = Color(0xFF141414);
  static const Color accentPrimary = Color(0xFFE50914);
  static const Color accentDanger = Color(0xFF8B1515);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF888888);
  static const Color textMuted = Color(0xFF555555);
  static const Color borderSubtle = Color(0xFF222222);
  static const Color divider = Color(0xFF1A1A1A);
  static const Color selectionOverlay = Color(0x22E50914);
}
