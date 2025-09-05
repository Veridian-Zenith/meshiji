import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'explorer_home.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FileExplorerApp());
}

class FileExplorerApp extends StatelessWidget {
  const FileExplorerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Meshiji',
      theme: base.copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: base.colorScheme.copyWith(primary: AppTheme.goldAccent, secondary: AppTheme.gold),
        textTheme: GoogleFonts.gamjaFlowerTextTheme(base.textTheme).apply(
          bodyColor: AppTheme.gold,
          displayColor: AppTheme.gold,
        ),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.black, elevation: 0),
      ),
      home: const ExplorerHome(title: 'Meshiji'),
    );
  }
}
