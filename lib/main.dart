import 'dart:io';
import 'dart:ui';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path/path.dart' as p;
import 'package:visibility_detector/visibility_detector.dart';
import 'plugin_manager.dart';
import 'settings_manager.dart';
import 'trash_manager.dart';

// Helper to compute directory size in a background isolate
int _computeDirectorySize(String path) {
  try {
    final dir = Directory(path);
    if (!dir.existsSync()) return 0;
    int total = 0;
    for (final entry in dir.listSync(recursive: true, followLinks: false)) {
      try {
        if (entry is File) total += entry.lengthSync();
      } catch (_) {}
    }
    return total;
  } catch (_) {
    return 0;
  }
}

enum SortMode { name, modified }

/// Simple in-memory cache with a queued, throttled background worker for
/// computing directory sizes. Call `requestSize(path, cb)` to get notified
/// when the size is available. `clear()` clears the cache and pending listeners.
class SizeCache {
  SizeCache._();
  static final SizeCache instance = SizeCache._();

  final Map<String, int> _cache = {};
  final Map<String, List<void Function(int)>> _listeners = {};
  final List<String> _queue = [];
  int _running = 0;
  int concurrency = 2; // tune this for IO throughput; adjustable at runtime

  void setConcurrency(int c) {
    concurrency = c.clamp(1, 8);
    // try to start more if possible
    Future.microtask(_maybeStartNext);
  }

  void requestSize(String path, void Function(int) cb) {
    // if cached, return immediately
    if (_cache.containsKey(path)) {
      cb(_cache[path]!);
      return;
    }

    // register listener
    _listeners.putIfAbsent(path, () => []).add(cb);

    // if already queued, nothing else
    if (_queue.contains(path)) return;

    _queue.add(path);
    _maybeStartNext();
  }

  void _maybeStartNext() {
    while (_running < concurrency && _queue.isNotEmpty) {
      final path = _queue.removeAt(0);
      _running++;
      compute<String, int>(_computeDirectorySize, path).then((size) {
        _cache[path] = size;
        final listeners = _listeners.remove(path) ?? [];
        for (final l in listeners) {
          try {
            l(size);
          } catch (_) {}
        }
      }).whenComplete(() {
        _running--;
        // schedule next
        Future.microtask(_maybeStartNext);
      });
    }
  }

  void clear() {
    _cache.clear();
    _listeners.clear();
    _queue.clear();
    _running = 0;
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FileExplorerApp());
}

class FileExplorerApp extends StatelessWidget {
  const FileExplorerApp({super.key});

  static const Color gold = Color(0xFFFFD700);
  static const Color goldAccent = Color(0xFFFFE28A);

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mystic File Explorer',
      theme: base.copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: base.colorScheme.copyWith(primary: goldAccent, secondary: gold),
        textTheme: GoogleFonts.gamjaFlowerTextTheme(base.textTheme).apply(
          bodyColor: gold,
          displayColor: gold,
        ),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.black, elevation: 0),
      ),
      home: const ExplorerHome(title: 'Mystic File Explorer'),
    );
  }
}

class ExplorerHome extends StatefulWidget {
  const ExplorerHome({super.key, required this.title});
  final String title;

  @override
  State<ExplorerHome> createState() => _ExplorerHomeState();
}

class _ExplorerHomeState extends State<ExplorerHome> {
  Directory currentDir = Directory.current;
  String _query = '';
  SortMode _sortMode = SortMode.name;
  Timer? _searchDebounce;
  // Plugin settings
  bool _autoCompute = true;
  bool _lowSpec = false;
  bool _pluginsEnabled = false;
  bool _pluginProcessIsolation = false;
  List<FileSystemEntity> _files = [];
  bool _isLoading = true;

  final PluginManager _pluginManager = PluginManager();
  final SettingsManager _settingsManager = SettingsManager();

  @override
  void initState() {
    super.initState();
    _loadSettingsAndFiles();
    _pluginManager.loadPlugins();
  }

  Future<void> _loadSettingsAndFiles() async {
    await _settingsManager.loadSettings();
    setState(() {
      _autoCompute = _settingsManager.settings['autoCompute'] as bool;
      _lowSpec = _settingsManager.settings['lowSpec'] as bool;
      _pluginsEnabled = _settingsManager.settings['pluginsEnabled'] as bool;
      _pluginProcessIsolation = _settingsManager.settings['pluginProcessIsolation'] as bool;
      SizeCache.instance.setConcurrency(_settingsManager.settings['concurrency'] as int);
    });
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final children = await compute<Directory, List<FileSystemEntity>>((dir) => dir.listSync(), currentDir);
      final filtered = children.where((e) => p.basename(e.path).toLowerCase().contains(_query.toLowerCase())).toList();
      filtered.sort((a, b) {
        final aDir = FileSystemEntity.isDirectorySync(a.path);
        final bDir = FileSystemEntity.isDirectorySync(b.path);
        if (aDir && !bDir) return -1;
        if (!aDir && bDir) return 1;
        switch (_sortMode) {
          case SortMode.name:
            return p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase());
          case SortMode.modified:
            try {
              final am = FileSystemEntity.isDirectorySync(a.path) ? Directory(a.path).statSync().modified : File(a.path).statSync().modified;
              final bm = FileSystemEntity.isDirectorySync(b.path) ? Directory(b.path).statSync().modified : File(b.path).statSync().modified;
              return bm.compareTo(am);
            } catch (_) {
              return 0;
            }
        }
      });
      if (mounted) {
        setState(() {
          _files = filtered;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _files = [];
          _isLoading = false;
        });
      }
    }
  }

  void _refreshAll() {
    SizeCache.instance.clear();
    _loadFiles();
  }

  void _goToDir(Directory dir) {
    if (!dir.existsSync()) return;
    currentDir = dir;
    _loadFiles();
  }

  void _goUp() {
    final parent = currentDir.parent;
    if (parent.path != currentDir.path) _goToDir(parent);
  }

  void _openSettings() {
    showDialog(context: context, builder: (_) => _buildSettingsDialog(context));
  }

  @override
  Widget build(BuildContext context) {
    // Placeholder usage to remove unused warnings
    if (_pluginsEnabled) {}
    if (_pluginProcessIsolation) {}

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // subtle radial glow in background
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Colors.black,
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 0.5, sigmaY: 0.5),
                  child: const SizedBox.shrink(),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _goUp,
                        icon: const Icon(Icons.arrow_upward, color: FileExplorerApp.gold),
                        tooltip: 'Go up',
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentDir.path,
                              style: const TextStyle(color: FileExplorerApp.gold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 36,
                                    child: TextField(
                                      onChanged: (v) {
                                        _searchDebounce?.cancel();
                                        _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                                          if (mounted) setState(() => _query = v);
                                        });
                                      },
                                      style: const TextStyle(color: FileExplorerApp.gold, fontSize: 14),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: const Color.fromRGBO(0,0,0,0.25),
                                        prefixIcon: const Icon(Icons.search, color: FileExplorerApp.gold),
                                        hintText: 'Search',
                                        hintStyle: const TextStyle(color: Color.fromRGBO(255,215,0,0.7)),
                                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(color: const Color.fromRGBO(0,0,0,0.2), borderRadius: BorderRadius.circular(8)),
                                  child: DropdownButton<SortMode>(
                                    dropdownColor: Colors.black,
                                    value: _sortMode,
                                    items: const [
                                      DropdownMenuItem(value: SortMode.name, child: Text('Name', style: TextStyle(color: FileExplorerApp.gold))),
                                      DropdownMenuItem(value: SortMode.modified, child: Text('Modified', style: TextStyle(color: FileExplorerApp.gold))),
                                    ],
                                    onChanged: (v) => setState(() { if (v != null) _sortMode = v; }),
                                    underline: const SizedBox.shrink(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(onPressed: _refreshAll, icon: const Icon(Icons.refresh, color: FileExplorerApp.gold)),
                                const SizedBox(width: 8),
                                // toggles
                                Tooltip(
                                  message: 'Auto-compute folder sizes',
                                  child: Row(
                                    children: [
                                      const Text('Auto', style: TextStyle(color: FileExplorerApp.gold, fontSize: 12)),
                                      Switch(value: _autoCompute, activeThumbColor: FileExplorerApp.gold, onChanged: (v) {
                                        setState(() => _autoCompute = v);
                                        _settingsManager.saveSettings(autoCompute: v);
                                      }),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Tooltip(
                                  message: 'Low-spec mode: reduce animations and IO pressure',
                                  child: Row(
                                    children: [
                                      const Text('LowSpec', style: TextStyle(color: FileExplorerApp.gold, fontSize: 12)),
                                      Switch(value: _lowSpec, activeThumbColor: FileExplorerApp.gold, onChanged: (v) {
                                        setState(() {
                                          _lowSpec = v;
                                          SizeCache.instance.setConcurrency(v ? 1 : 2);
                                        });
                                        _settingsManager.saveSettings(lowSpec: v, concurrency: v ? 1 : 2);
                                      }),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // settings gear (styled container matching file icon style)
                                GestureDetector(
                                  onTap: _openSettings,
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: const Color.fromRGBO(0, 0, 0, 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color.fromRGBO(255, 215, 0, 0.2)),
                                    ),
                                    child: const Icon(Icons.settings, color: FileExplorerApp.gold),
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(FileExplorerApp.gold)))
                        : ScrollConfiguration(
                            behavior: const _NoGlowScrollBehavior(),
                            child: ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              itemCount: _files.length,
                              itemBuilder: (context, index) {
                                final entity = _files[index];
                                final isDir = FileSystemEntity.isDirectorySync(entity.path);
                                final tile = VisibilityDetector(
                                  key: Key(entity.path),
                                  onVisibilityChanged: (info) {
                                    if (_autoCompute && info.visibleFraction > 0.05) {
                                      // request size computation when the tile becomes at least slightly visible
                                      if (isDir) SizeCache.instance.requestSize(entity.path, (_) {});
                                    }
                                  },
                                  child: _FileTile(
                                    name: p.basename(entity.path),
                                    path: entity.path,
                                    isDirectory: isDir,
                                    onTap: isDir ? () => _goToDir(Directory(entity.path)) : null,
                                  ),
                                );

                                if (_lowSpec) return tile;

                                return tile.animate().fade(duration: 350.ms).scale(duration: 350.ms, curve: Curves.easeOutBack);
                              },
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FileTile extends StatefulWidget {
  final String name;
  final String path;
  final bool isDirectory;
  final VoidCallback? onTap;

  const _FileTile({required this.name, required this.path, required this.isDirectory, this.onTap});

  @override
  State<_FileTile> createState() => _FileTileState();
}

class _FileTileState extends State<_FileTile> {
  bool _hovering = false;
  String _meta = '';
  bool _computingFolderSize = false;

  Future<void> _maybeComputeFolderSize() async {
    if (!widget.isDirectory) return;
    setState(() => _computingFolderSize = true);
    SizeCache.instance.requestSize(widget.path, (size) {
      final sizeText = _readableFileSize(size);
      if (mounted) setState(() => _meta = '$sizeText • Folder');
      if (mounted) setState(() => _computingFolderSize = false);
    });
  }

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  void _loadMeta() {
    try {
      final entity = FileSystemEntity.typeSync(widget.path) == FileSystemEntityType.directory
          ? null
          : File(widget.path);
      if (entity == null) {
  _meta = 'Folder';
  // compute folder size async
  _maybeComputeFolderSize();
      } else {
        final stat = entity.statSync();
        final size = stat.size;
        final modified = stat.modified;
        final sizeText = _readableFileSize(size);
  _meta = '$sizeText • ${_shortDate(modified)}';
      }
    } catch (e) {
    _meta = '';
    }
  }

  String _shortDate(DateTime dt) {
  final y = dt.year;
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
  }

  String _readableFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kib = bytes / 1024;
  if (kib < 1024) return '${kib.toStringAsFixed(1)} KiB';
  final mib = kib / 1024;
  if (mib < 1024) return '${mib.toStringAsFixed(1)} MiB';
  final gib = mib / 1024;
  if (gib < 1024) return '${gib.toStringAsFixed(1)} GiB';
  final tib = gib / 1024;
  return '${tib.toStringAsFixed(1)} TiB';
  }

  void _setHover(bool v) => setState(() => _hovering = v);

  @override
  Widget build(BuildContext context) {
    final borderColor = _hovering ? FileExplorerApp.goldAccent : FileExplorerApp.gold;
  final shadowColor = Color.fromRGBO(255, 215, 0, _hovering ? 0.14 : 0.06);

    final content = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(0, 0, 0, 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  widget.isDirectory ? Icons.folder : Icons.insert_drive_file,
                  color: FileExplorerApp.goldAccent,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.name,
                      style: const TextStyle(
                        color: FileExplorerApp.gold,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_meta.isNotEmpty) const SizedBox(height: 4),
                    if (_computingFolderSize)
                      const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(FileExplorerApp.gold))),
                    if (!_computingFolderSize && _meta.isNotEmpty)
                      Text(
                        _meta,
                        style: const TextStyle(
                          color: Color.fromRGBO(255, 215, 0, 0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                color: Colors.black,
                icon: const Icon(Icons.more_vert, color: Color.fromRGBO(255,215,0,0.9)),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'open', child: Text('Open', style: TextStyle(color: FileExplorerApp.gold))),
                  const PopupMenuItem(value: 'reveal', child: Text('Reveal in file manager', style: TextStyle(color: FileExplorerApp.gold))),
                  const PopupMenuItem(value: 'delete', child: Text('Delete (placeholder)', style: TextStyle(color: FileExplorerApp.gold))),
                ],
                onSelected: (v) async {
                  if (v == 'open' && widget.isDirectory) {
                    widget.onTap?.call();
                  } else if (v == 'reveal') {
                    // attempt to open native file manager when available
                    try {
                      if (defaultTargetPlatform == TargetPlatform.linux) {
                        Process.run('xdg-open', [p.dirname(widget.path)]);
                      } else if (defaultTargetPlatform == TargetPlatform.windows) {
                        Process.run('explorer', [p.dirname(widget.path)]);
                      } else if (defaultTargetPlatform == TargetPlatform.macOS) {
                        Process.run('open', [p.dirname(widget.path)]);
                      }
                    } catch (_) {}
                  } else if (v == 'delete') {
                    // Implement safe delete with confirmation
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: Colors.black,
                        title: const Text('Confirm Delete', style: TextStyle(color: FileExplorerApp.gold)),
                        content: Text('Are you sure you want to move "${widget.name}" to trash?', style: const TextStyle(color: FileExplorerApp.gold)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel', style: TextStyle(color: FileExplorerApp.goldAccent)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      try {
                        await TrashManager.moveToTrash(widget.path);
                        // Refresh the file list after deletion
                        if (mounted) widget.onTap?.call(); // Assuming onTap triggers a refresh in parent
                      } catch (e) {
                        debugPrint('Failed to move to trash: $e');
                        // Optionally show an error message to the user
                      }
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );

    final decorated = DottedBorder(
      color: borderColor,
      strokeWidth: 1.0,
      dashPattern: const [2, 4],
      borderType: BorderType.RRect,
      radius: const Radius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              const Color.fromRGBO(255, 215, 0, 0.02),
              const Color.fromRGBO(0, 0, 0, 0.36),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: _hovering ? 12 : 6,
              spreadRadius: _hovering ? 0.6 : 0.2,
            ),
          ],
        ),
        child: content,
      ),
    );

    if (kIsWeb || defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux) {
      return MouseRegion(
        onEnter: (_) => _setHover(true),
        onExit: (_) => _setHover(false),
        cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
        child: decorated,
      );
    }

    // mobile: use gesture feedback only
    return GestureDetector(
      onTapDown: (_) => _setHover(true),
      onTapUp: (_) => _setHover(false),
      onTapCancel: () => _setHover(false),
      onTap: widget.onTap,
      child: decorated,
    );
  }
}

class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;
}

// Refactored to a StatefulWidget for better state management and performance.
class _SettingsDialog extends StatefulWidget {
  final SettingsManager settingsManager;
  final _ExplorerHomeState explorerState;
  final bool initialPluginsEnabled;
  final bool initialPluginProcessIsolation;
  final int initialConcurrency;

  const _SettingsDialog({
    required this.settingsManager,
    required this.explorerState,
    required this.initialPluginsEnabled,
    required this.initialPluginProcessIsolation,
    required this.initialConcurrency,
  });

  @override
  __SettingsDialogState createState() => __SettingsDialogState();
}

class __SettingsDialogState extends State<_SettingsDialog> {
  late bool _pluginsEnabled;
  late bool _pluginProcessIsolation;
  late int _concurrency;

  @override
  void initState() {
    super.initState();
    _pluginsEnabled = widget.initialPluginsEnabled;
    _pluginProcessIsolation = widget.initialPluginProcessIsolation;
    _concurrency = widget.initialConcurrency;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Settings', style: TextStyle(color: FileExplorerApp.gold, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            const Text('Performance', style: TextStyle(color: FileExplorerApp.gold, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('- Auto compute folder sizes: toggled from main UI', style: TextStyle(color: FileExplorerApp.gold)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Concurrency (1-8)', style: TextStyle(color: FileExplorerApp.gold)),
                DropdownButton<int>(
                  dropdownColor: Colors.black,
                  value: _concurrency,
                  items: List.generate(8, (index) => index + 1)
                      .map((e) => DropdownMenuItem(value: e, child: Text('$e', style: const TextStyle(color: FileExplorerApp.gold))))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _concurrency = v);
                      widget.settingsManager.saveSettings(concurrency: v);
                      SizeCache.instance.setConcurrency(v);
                    }
                  },
                  underline: const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Plugins', style: TextStyle(color: FileExplorerApp.gold, fontSize: 14, fontWeight: FontWeight.w600)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Enable plugins', style: TextStyle(color: FileExplorerApp.gold)),
                Switch(
                  value: _pluginsEnabled,
                  activeThumbColor: FileExplorerApp.gold,
                  onChanged: (v) {
                    setState(() => _pluginsEnabled = v);
                    widget.settingsManager.saveSettings(pluginsEnabled: v);
                  },
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Per-plugin process isolation', style: TextStyle(color: FileExplorerApp.gold)),
                Switch(
                  value: _pluginProcessIsolation,
                  activeThumbColor: FileExplorerApp.gold,
                  onChanged: _pluginsEnabled
                      ? (v) {
                          setState(() => _pluginProcessIsolation = v);
                          widget.settingsManager.saveSettings(pluginProcessIsolation: v);
                        }
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Future features', style: TextStyle(color: FileExplorerApp.gold, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('- Built-in terminal (TBD)', style: TextStyle(color: FileExplorerApp.gold)),
            const SizedBox(height: 6),
            const Text('- File previews, more actions (TBD)', style: TextStyle(color: FileExplorerApp.gold)),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    // Update the main explorer state with the new settings
                    widget.explorerState.setState(() {
                      widget.explorerState._pluginsEnabled = _pluginsEnabled;
                      widget.explorerState._pluginProcessIsolation = _pluginProcessIsolation;
                      widget.explorerState._autoCompute = widget.settingsManager.settings['autoCompute'] as bool;
                      widget.explorerState._lowSpec = widget.settingsManager.settings['lowSpec'] as bool;
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text('Close', style: TextStyle(color: FileExplorerApp.gold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildSettingsDialog(BuildContext context) {
  final state = context.findAncestorStateOfType<_ExplorerHomeState>()!;
  return _SettingsDialog(
    settingsManager: state._settingsManager,
    explorerState: state,
    initialPluginsEnabled: state._pluginsEnabled,
    initialPluginProcessIsolation: state._pluginProcessIsolation,
    initialConcurrency: state._settingsManager.settings['concurrency'] as int,
  );
}
