import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path/path.dart' as p;
import 'package:visibility_detector/visibility_detector.dart';
import 'file_tile.dart';
import 'plugin_manager.dart';
import 'settings_manager.dart';
import 'settings_dialog.dart';
import 'size_cache.dart';
import 'trash_manager.dart'; // Added import for TrashManager
import 'utils.dart';
import 'app_theme.dart';

const double _kTabletBreakpoint = 800.0; // Define a breakpoint for responsive layout

enum SortMode { name, modified }

class ExplorerHome extends StatefulWidget {
  const ExplorerHome({super.key, required this.title});
  final String title;

  @override
  State<ExplorerHome> createState() => ExplorerHomeState();
}

class ExplorerHomeState extends State<ExplorerHome> {
  Directory currentDir = Directory.current;
  String query = '';
  SortMode sortMode = SortMode.name;
  Timer? searchDebounce;
  // Plugin settings
  bool autoCompute = true;
  bool lowSpec = false;
  bool pluginsEnabled = false;
  bool pluginProcessIsolation = false;
  bool builtInTerminalEnabled = false;
  bool luaPluginSupportEnabled = false;
  List<FileSystemEntity> files = [];
  bool isLoading = true;

  final PluginManager pluginManager = PluginManager();
  final SettingsManager settingsManager = SettingsManager();

  @override
  void initState() {
    super.initState();
    _loadSettingsAndFiles();
    pluginManager.loadPlugins();
  }

  Future<void> _loadSettingsAndFiles() async {
    await settingsManager.loadSettings();
    setState(() {
      autoCompute = settingsManager.settings['autoCompute'] as bool;
      lowSpec = settingsManager.settings['lowSpec'] as bool;
      pluginsEnabled = settingsManager.settings['pluginsEnabled'] as bool;
      pluginProcessIsolation = settingsManager.settings['pluginProcessIsolation'] as bool;
      builtInTerminalEnabled = settingsManager.settings['builtInTerminalEnabled'] as bool;
      luaPluginSupportEnabled = settingsManager.settings['luaPluginSupportEnabled'] as bool;
      SizeCache.instance.setConcurrency(settingsManager.settings['concurrency'] as int);
    });
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final children = await compute<Directory, List<FileSystemEntity>>((dir) => dir.listSync(), currentDir);
      final filtered = children.where((e) => p.basename(e.path).toLowerCase().contains(query.toLowerCase())).toList();
      filtered.sort((a, b) {
        final aDir = FileSystemEntity.isDirectorySync(a.path);
        final bDir = FileSystemEntity.isDirectorySync(b.path);
        if (aDir && !bDir) return -1;
        if (!aDir && bDir) return 1;
        switch (sortMode) {
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
          files = filtered;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          files = [];
          isLoading = false;
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
    showDialog(context: context, builder: (_) => buildSettingsDialog(context, this));
  }

  Future<void> _createFolder() async {
    String? folderName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text('Create New Folder', style: TextStyle(color: AppTheme.gold)),
        content: TextField(
          autofocus: true,
          style: const TextStyle(color: AppTheme.gold),
          decoration: const InputDecoration(
            hintText: 'Folder Name',
            hintStyle: TextStyle(color: Color.fromRGBO(255,215,0,0.7)),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.goldAccent)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(''), // Empty string to indicate creation
            child: const Text('Create', style: TextStyle(color: AppTheme.gold)),
          ),
        ],
      ),
    );

    if (folderName != null && folderName.isNotEmpty) {
      try {
        final newDirPath = p.join(currentDir.path, folderName);
        await Directory(newDirPath).create();
        _loadFiles(); // Refresh the file list
      } catch (e) {
        debugPrint('Error creating folder: $e');
        // Optionally show an error message to the user
      }
    }
  }

  Future<void> _restoreFile(String path) async {
    try {
      await TrashManager.restoreFromTrash(path);
      _loadFiles(); // Refresh the file list
    } catch (e) {
      debugPrint('Failed to restore from trash: $e');
      // Optionally show an error message to the user
    }
  }

  Future<void> _deletePermanently(String path) async {
    try {
      final entity = FileSystemEntity.typeSync(path) == FileSystemEntityType.directory
          ? Directory(path)
          : File(path);
      if (entity.existsSync()) {
        await entity.delete(recursive: true);
        _loadFiles(); // Refresh the file list
      }
    } catch (e) {
      debugPrint('Failed to delete permanently: $e');
      // Optionally show an error message to the user
    }
  }

  @override
  Widget build(BuildContext context) {
    // Placeholder usage to remove unused warnings
    if (pluginsEnabled) {}
    if (pluginProcessIsolation) {}

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool showPersistentSidebar = screenWidth > _kTabletBreakpoint;

    Widget sidebarContent = ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0), // Adjusted padding for title
          child: Text(
            'Quick Access',
            style: TextStyle(
              color: AppTheme.gold,
              fontSize: 16, // Slightly smaller font size
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ListTile(
          leading: Icon(Icons.home, color: AppTheme.gold),
          title: Text('Home', style: TextStyle(color: AppTheme.gold)),
          onTap: () {
            _goToDir(Directory(getUserHomeDirectory()));
            if (!showPersistentSidebar) Navigator.pop(context);
          },
        ),
        ListTile(
          leading: Icon(Icons.folder, color: AppTheme.gold),
          title: Text('Documents', style: TextStyle(color: AppTheme.gold)),
          onTap: () {
            _goToDir(Directory(p.join(getUserHomeDirectory(), 'Documents')));
            if (!showPersistentSidebar) Navigator.pop(context);
          },
        ),
        ListTile(
          leading: Icon(Icons.download, color: AppTheme.gold),
          title: Text('Downloads', style: TextStyle(color: AppTheme.gold)),
          onTap: () {
            _goToDir(Directory(p.join(getUserHomeDirectory(), 'Downloads')));
            if (!showPersistentSidebar) Navigator.pop(context);
          },
        ),
        ListTile(
          leading: Icon(Icons.delete, color: AppTheme.gold),
          title: Text('Trash', style: TextStyle(color: AppTheme.gold)),
          onTap: () {
            _goToDir(Directory(p.join(getUserHomeDirectory(), '.local', 'share', 'Trash', 'files')));
            if (!showPersistentSidebar) Navigator.pop(context);
          },
        ),
      ],
    );

    Widget mainContent = SafeArea(
      child: Stack(
        children: [
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
                    if (!showPersistentSidebar) // Only show menu button if sidebar is not persistent
                      Builder(
                        builder: (context) => IconButton(
                          onPressed: () => Scaffold.of(context).openDrawer(),
                          icon: const Icon(Icons.menu, color: AppTheme.gold),
                          tooltip: 'Open sidebar',
                        ),
                      ),
                    IconButton(
                      onPressed: _goUp,
                      icon: const Icon(Icons.arrow_upward, color: AppTheme.gold),
                      tooltip: 'Go up',
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentDir.path,
                            style: const TextStyle(color: AppTheme.gold, fontSize: 14),
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
                                      searchDebounce?.cancel();
                                      searchDebounce = Timer(const Duration(milliseconds: 300), () {
                                        if (mounted) setState(() => query = v);
                                      });
                                    },
                                    style: const TextStyle(color: AppTheme.gold, fontSize: 14),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: const Color.fromRGBO(0,0,0,0.25),
                                      prefixIcon: const Icon(Icons.search, color: AppTheme.gold),
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
                                  value: sortMode,
                                  items: const [
                                    DropdownMenuItem(value: SortMode.name, child: Text('Name', style: TextStyle(color: AppTheme.gold))),
                                    DropdownMenuItem(value: SortMode.modified, child: Text('Modified', style: TextStyle(color: AppTheme.gold))),
                                  ],
                                  onChanged: (v) => setState(() { if (v != null) sortMode = v; }),
                                  underline: const SizedBox.shrink(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(onPressed: _refreshAll, icon: const Icon(Icons.refresh, color: AppTheme.gold)),
                              const SizedBox(width: 8),
                              Tooltip(
                                message: 'Auto-compute folder sizes',
                                child: Row(
                                  children: [
                                    const Text('Auto', style: TextStyle(color: AppTheme.gold, fontSize: 12)),
                                    Switch(value: autoCompute, activeThumbColor: AppTheme.gold, onChanged: (v) {
                                      setState(() => autoCompute = v);
                                      settingsManager.saveSettings(autoCompute: v);
                                    }),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Tooltip(
                                message: 'Low-spec mode: reduce animations and IO pressure',
                                child: Row(
                                  children: [
                                    const Text('LowSpec', style: TextStyle(color: AppTheme.gold, fontSize: 12)),
                                    Switch(value: lowSpec, activeThumbColor: AppTheme.gold, onChanged: (v) {
                                      setState(() {
                                        lowSpec = v;
                                        SizeCache.instance.setConcurrency(v ? 1 : 2);
                                      });
                                      settingsManager.saveSettings(lowSpec: v, concurrency: v ? 1 : 2);
                                    }),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
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
                                  child: const Icon(Icons.settings, color: AppTheme.gold),
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
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.gold)))
                      : ScrollConfiguration(
                          behavior: const NoGlowScrollBehavior(),
                          child: ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            itemCount: files.length,
                            itemBuilder: (context, index) {
                              final entity = files[index];
                              final isDir = FileSystemEntity.isDirectorySync(entity.path);
                              final tile = VisibilityDetector(
                                key: Key(entity.path),
                                onVisibilityChanged: (info) {
                                  if (autoCompute && info.visibleFraction > 0.05) {
                                    if (isDir) SizeCache.instance.requestSize(entity.path, (_) {});
                                  }
                                },
                                  child: FileTile(
                                    name: p.basename(entity.path),
                                    path: entity.path,
                                    isDirectory: isDir,
                                    onTap: isDir ? () => _goToDir(Directory(entity.path)) : null,
                                    onCreateFolder: _createFolder,
                                    isTrashDirectory: currentDir.path.startsWith(p.join(getUserHomeDirectory(), '.local', 'share', 'Trash', 'files')), // Check if current directory is within trash
                                    onRestore: _restoreFile,
                                    onDeletePermanently: _deletePermanently,
                                  ),
                                );

                              if (lowSpec) return tile;

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
    );

    if (showPersistentSidebar) {
      return Scaffold(
        body: Row(
          children: [
            Container(
              width: 180, // Further reduced width for persistent sidebar
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8), // Blend with existing style
                border: Border(right: BorderSide(color: AppTheme.gold.withOpacity(0.2), width: 1)),
              ),
              child: sidebarContent,
            ),
            Expanded(child: mainContent),
          ],
        ),
      );
    } else {
      return Scaffold(
        drawer: Drawer(
          backgroundColor: Colors.black,
          child: sidebarContent,
        ),
        body: mainContent,
      );
    }
  }
}
