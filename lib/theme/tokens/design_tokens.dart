import 'package:flutter/material.dart';

class DesignTokens {
  // Primitive Tokens
  static const Color colorBlack = Color(0xFF0D1117);
  static const Color colorBlueBlack = Color(0xFF010409);
  static const Color colorGold = Color(0xFFFFD700);
  static const Color colorAmber = Color(0xFFFFB347);
  static const Color colorRed = Color(0xFFD72638);
  static const Color colorWhite = Color(0xFFF0F6FC);
  static const Color colorGrey = Color(0xFF8B949E);

  static const double spacingBase = 8.0;
  static const double radiusBase = 4.0;
  static const Duration durationFast = Duration(milliseconds: 120);
  static const Duration durationStandard = Duration(milliseconds: 200);
  static const Duration durationEmphasis = Duration(milliseconds: 320);

  // Semantic Tokens
  static const Color backgroundPrimary = Color.fromARGB(255, 0, 0, 0);
  static const Color backgroundSecondary = colorBlack;
  static const Color surfacePrimary = Color.fromARGB(255, 0, 0, 0);
  static const Color surfaceElevated = Color(0xFF161B22);
  static const Color accentPrimary = Color.fromARGB(255, 215, 144, 45);
  static const Color accentDanger = Color.fromARGB(255, 175, 22, 37);
  static const Color textPrimary = Color.fromARGB(255, 216, 221, 227);
  static const Color textSecondary = Color.fromARGB(255, 113, 119, 126);
  static const Color textMuted = Color.fromARGB(255, 69, 75, 82);
  static const Color borderSubtle = Color(0xFF30363D);
  static const Color divider = Color(0xFF21262D);
  static const Color selectionOverlay = Color(0x33FFB347);
}
