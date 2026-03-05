import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:meshiji/features/explorer/presentation/explorer_page.dart';
import 'package:meshiji/shared/widgets/app_background.dart';
import 'package:meshiji/theme/app_theme.dart';
import 'package:window_manager/window_manager.dart';

class MeshijiApp extends StatefulWidget {
  const MeshijiApp({super.key});

  @override
  State<MeshijiApp> createState() => _MeshijiAppState();
}

class _MeshijiAppState extends State<MeshijiApp> with WindowListener {
  bool _wasFocused = false;
  Timer? _borderFixDebounce;

  @override
  void initState() {
    super.initState();
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      windowManager.addListener(this);
      // Start focus polling for Linux Wayland
      if (Platform.isLinux) {
        _startFocusPolling();
      }
    }
  }

  void _startFocusPolling() {
    // Poll focus changes - necessary because onWindowFocus doesn't always fire on workspace switch
    Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final isFocused = await windowManager.isFocused();
      if (isFocused != _wasFocused) {
        _wasFocused = isFocused;
        if (isFocused) {
          // We just gained focus - likely switched to this workspace
          _triggerBorderRefresh();
        }
      }
    });
  }

  void _triggerBorderRefresh() {
    _borderFixDebounce?.cancel();
    _borderFixDebounce = Timer(const Duration(milliseconds: 50), () async {
      // Method 1: Minimize and restore (forces full reconfigure)
      // await windowManager.minimize();
      // await windowManager.restore();

      // Method 2: Toggle visibility
      // await windowManager.hide();
      // await Future.delayed(const Duration(milliseconds: 10));
      // await windowManager.show();

      // Method 3: Resize nudge (least disruptive)
      final size = await windowManager.getSize();
      await windowManager.setSize(Size(size.width + 1, size.height));
      await windowManager.setSize(size);

      // Method 4: Set minimum size then restore (forces decoration renegotiation)
      // final minSize = await windowManager.getMinimumSize();
      // await windowManager.setMinimumSize(const Size(0, 0));
      // await windowManager.setMinimumSize(minSize);
    });
  }

  @override
  void dispose() {
    _borderFixDebounce?.cancel();
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowMove() {
    // Keep existing as fallback
    _triggerBorderRefresh();
  }

  @override
  void onWindowFocus() {
    // Backup detection method
    _triggerBorderRefresh();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meshiji',
      theme: AppTheme.darkTheme,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            const AppBackground(),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: ExplorerPage(),
            ),
          ],
        ),
      ),
    );
  }
}
