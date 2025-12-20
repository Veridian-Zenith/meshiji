import 'package:flutter/material.dart';
import 'utils/app_theme.dart';
import 'screens/file_explorer_screen.dart';

void main() {
  runApp(const FileExplorerApp());
}

class FileExplorerApp extends StatelessWidget {
  const FileExplorerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meshiji File Explorer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: FileExplorerScreen(),
    );
  }
}
