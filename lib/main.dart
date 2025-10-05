import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'explorer_home.dart';
import 'logger.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();

    // Set up error handling for the entire app
    FlutterError.onError = (FlutterErrorDetails details) {
      Logger.instance.error('Flutter Error', details.exception, details.stack);
    };

    // Initialize logger
    Logger.instance.info('Meshiji File Explorer starting up');

    runApp(const FileExplorerApp());
  }, (Object error, StackTrace stack) {
    Logger.instance.error('Unhandled error in main zone', error, stack);
  });
}

class FileExplorerApp extends StatelessWidget {
  const FileExplorerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Meshiji - Elegant File Explorer',
      theme: base.copyWith(
        scaffoldBackgroundColor: AppTheme.background,
        primaryColor: AppTheme.goldAccent,
        colorScheme: base.colorScheme.copyWith(
          primary: AppTheme.goldAccent,
          secondary: AppTheme.rosewaterAccent,
          surface: AppTheme.surface,
          background: AppTheme.background,
          error: AppTheme.error,
          onPrimary: AppTheme.background,
          onSecondary: AppTheme.background,
          onSurface: AppTheme.textSecondary,
          onBackground: AppTheme.textPrimary,
        ),
        textTheme: GoogleFonts.gamjaFlowerTextTheme(base.textTheme).apply(
          bodyColor: AppTheme.textSecondary,
          displayColor: AppTheme.textPrimary,
        ).copyWith(
          // Enhanced typography hierarchy
          displayLarge: AppTheme.displayLarge.copyWith(fontFamily: 'GamjaFlower'),
          displayMedium: AppTheme.displayMedium.copyWith(fontFamily: 'GamjaFlower'),
          headlineLarge: AppTheme.headingLarge.copyWith(fontFamily: 'GamjaFlower'),
          headlineMedium: AppTheme.headingMedium.copyWith(fontFamily: 'GamjaFlower'),
          headlineSmall: AppTheme.headingSmall.copyWith(fontFamily: 'GamjaFlower'),
          bodyLarge: AppTheme.bodyLarge.copyWith(fontFamily: 'GamjaFlower'),
          bodyMedium: AppTheme.bodyMedium.copyWith(fontFamily: 'GamjaFlower'),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppTheme.background,
          elevation: AppTheme.elevationNone,
          shadowColor: AppTheme.shadowLight,
          surfaceTintColor: AppTheme.goldAccent,
        ),
        cardTheme: CardThemeData(
          color: AppTheme.surface,
          elevation: AppTheme.elevationSm,
          shadowColor: AppTheme.shadowLight,
          surfaceTintColor: AppTheme.goldAccent,
          margin: EdgeInsets.all(AppTheme.spacingXs),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.surfaceElevated,
            foregroundColor: AppTheme.textPrimary,
            elevation: AppTheme.elevationMd,
            shadowColor: AppTheme.shadowMedium,
            surfaceTintColor: AppTheme.goldAccent,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingLg,
              vertical: AppTheme.spacingMd,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            minimumSize: const Size(AppTheme.buttonHeight * 2, AppTheme.buttonHeight),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppTheme.surfaceLight,
          hintStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.textMuted),
          labelStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            borderSide: const BorderSide(color: AppTheme.goldAccent, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            borderSide: const BorderSide(color: AppTheme.goldAccent, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            borderSide: const BorderSide(color: AppTheme.goldAccent, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            borderSide: const BorderSide(color: AppTheme.error, width: 1),
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return AppTheme.goldAccent;
            }
            return AppTheme.textMuted;
          }),
          trackColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return AppTheme.goldAccent.withOpacity(0.5);
            }
            return AppTheme.surfaceLight;
          }),
        ),
        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: AppTheme.goldAccent,
          linearTrackColor: AppTheme.surfaceLight,
        ),
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: MaterialStateProperty.all(AppTheme.goldAccent.withOpacity(0.6)),
          trackColor: MaterialStateProperty.all(AppTheme.surfaceLight.withOpacity(0.3)),
          thickness: MaterialStateProperty.all(8),
          radius: const Radius.circular(AppTheme.radiusFull),
        ),
      ),
      home: const ExplorerHome(title: 'Meshiji'),
    );
  }
}
