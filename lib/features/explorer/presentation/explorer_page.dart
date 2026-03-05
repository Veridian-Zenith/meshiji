import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:meshiji/core/responsive/responsive_layout.dart';
import 'package:meshiji/features/explorer/presentation/widgets/directory_context_menu.dart';
import 'package:meshiji/features/explorer/presentation/widgets/file_context_menu.dart';
import 'package:meshiji/features/explorer/presentation/widgets/file_list_item.dart';
import 'package:meshiji/features/sidebar/sidebar.dart';
import 'package:meshiji/shared/widgets/dialogs.dart';
import 'package:meshiji/shared/widgets/frosted_glass.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

// (Data class and background fetch function remain the same)
class FileEntityWithMetadata {
  final FileSystemEntity entity;
  final FileStat stat;
  FileEntityWithMetadata(this.entity, this.stat);
}

Future<List<FileEntityWithMetadata>> _fetchAndSortFiles(Directory dir) async {
  final List<FileEntityWithMetadata> results = [];
  try {
    // Crucial Performance Upgrade: followLinks: false prevents traversing into heavy recursive symlink structures
    // that crash or slow down the file system sync reading tremendously on Linux.
    final files = dir.listSync(followLinks: false).toList();
    for (final entity in files) {
      try {
        results.add(FileEntityWithMetadata(entity, entity.statSync()));
      } catch (e) {
        // Ignore files that can't be stat-ed
      }
    }
    results.sort((a, b) {
      final aIsDir = a.entity is Directory;
      final bIsDir = b.entity is Directory;
      if (aIsDir && !bIsDir) return -1;
      if (!aIsDir && bIsDir) return 1;
      return a.entity.path.toLowerCase().compareTo(b.entity.path.toLowerCase());
    });
  } catch (e) {
    // Ignore errors reading the directory
  }
  return results;
}

class ExplorerPage extends StatefulWidget {
  const ExplorerPage({super.key});
  @override
  State<ExplorerPage> createState() => _ExplorerPageState();
}

class _ExplorerPageState extends State<ExplorerPage> {
  // (State variables and init methods remain mostly the same)
  double _sidebarWidth = 250.0;
  List<FileEntityWithMetadata> _files = [];
  Directory? _rootDir;
  Directory? _currentDir;
  bool _isLoading = true;
  final Map<String, bool> _hiddenFileVisibility = {};
  List<String> _pinnedPaths = [];
  final Set<String> _selectedFilePaths = {};
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _loadPinnedPaths();
    _requestPermissionAndLoadFiles();
  }

  // --- Core Business Logic ---
  Future<void> _loadFiles(Directory dir) async {
    if (!mounted) return;

    // Check if we're navigating to the same directory to avoid redundant reloads
    if (_currentDir?.path == dir.path && !_isLoading) return;

    setState(() {
      _isLoading = true;
      _selectedFilePaths.clear();
      _removeContextMenu();
    });

    final files = await compute(_fetchAndSortFiles, dir);

    if (!mounted) return;
    setState(() {
      _currentDir = dir;
      _files = files;
      _isLoading = false;
    });
  }

  void _deleteSelectedItems() async {
    if (_selectedFilePaths.isEmpty) return;

    final bool? confirmed = await showDeleteConfirmationDialog(
      context,
      _selectedFilePaths.length,
    );

    if (confirmed == true && mounted) {
      for (String path in _selectedFilePaths) {
        try {
          final entity = _files.firstWhere((f) => f.entity.path == path).entity;
          if (entity is Directory) {
            await entity.delete(recursive: true);
          } else {
            await entity.delete();
          }
        } catch (e) {
          // Optional: Show an error snackbar
        }
      }
      _selectedFilePaths.clear();
      await _loadFiles(_currentDir!);
    }
  }

  // --- Context Menu Logic ---
  void _showBackgroundContextMenu(
    BuildContext context,
    TapDownDetails details,
  ) {
    if (_currentDir == null) return;

    _removeContextMenu();

    final overlay = Overlay.of(context);
    final bool showHidden = _hiddenFileVisibility[_currentDir?.path] ?? false;

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: Listener(
              onPointerDown: (_) => _removeContextMenu(),
              behavior: HitTestBehavior.translucent,
            ),
          ),
          Positioned(
            top: details.globalPosition.dy,
            left: details.globalPosition.dx,
            child: DirectoryContextMenu(
              showHidden: showHidden,
              canPaste: false, // TBD: File copy/paste state
              onToggleHidden: () {
                setState(() {
                  _hiddenFileVisibility[_currentDir!.path] = !showHidden;
                });
              },
              onNewFolder: () {
                // TBD
              },
              onNewFile: () {
                // TBD
              },
              onPaste: () {
                // TBD
              },
              onDismiss: _removeContextMenu,
            ),
          ),
        ],
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  void _showContextMenu(
    BuildContext context,
    TapDownDetails details,
    FileEntityWithMetadata item,
  ) {
    _removeContextMenu(); // Remove any existing menu

    // Ensure the tapped item is part of the selection
    if (!_selectedFilePaths.contains(item.entity.path)) {
      setState(() {
        _selectedFilePaths.clear();
        _selectedFilePaths.add(item.entity.path);
      });
    }

    bool isDir = item.entity is Directory;
    bool isPinned = isDir && _pinnedPaths.contains(item.entity.path);

    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Fullscreen detector to close the menu when clicking away
          Positioned.fill(
            child: Listener(
              onPointerDown: (_) => _removeContextMenu(),
              behavior: HitTestBehavior.translucent,
            ),
          ),
          // The menu itself
          Positioned(
            top: details.globalPosition.dy,
            left: details.globalPosition.dx,
            child: FileContextMenu(
              entity: item.entity,
              isPinned: isPinned,
              onOpen: () => _handleFileDoubleTap(item.entity),
              onTogglePin: () => _togglePinPath(item.entity.path),
              onDelete: _deleteSelectedItems,
              onDismiss: _removeContextMenu,
            ),
          ),
        ],
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  void _removeContextMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  // --- Pinned Paths Logic ---
  Future<void> _loadPinnedPaths() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pinnedPaths = prefs.getStringList('pinnedPaths') ?? [];
    });
  }

  Future<void> _togglePinPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_pinnedPaths.contains(path)) {
        _pinnedPaths.remove(path);
      } else {
        _pinnedPaths.add(path);
      }
    });
    await prefs.setStringList('pinnedPaths', _pinnedPaths);
  }

  void _onSidebarResize(DragUpdateDetails details) {
    setState(() {
      _sidebarWidth = (_sidebarWidth + details.delta.dx).clamp(200.0, 500.0);
    });
  }

  Future<void> _requestPermissionAndLoadFiles() async {
    if (Platform.isAndroid) {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        await Permission.storage.request();
      }
    }
    await _getRootDir();
  }

  Future<void> _getRootDir() async {
    Directory? directory;
    if (Platform.isAndroid) {
      directory = await getExternalStorageDirectory();
    } else if (Platform.isLinux) {
      final String? home = Platform.environment['HOME'];
      if (home != null) {
        directory = Directory(home);
      }
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    if (mounted) {
      setState(() {
        _rootDir = directory;
      });
      if (directory != null) {
        await _loadPath(directory.path);
      }
    }
  }

  Future<void> _loadPath(String path) async {
    final dir = Directory(path);
    if (await dir.exists()) {
      await _loadFiles(dir);
    }
  }

  void _navigateToParent() {
    if (_currentDir != null && _currentDir!.parent.path != _currentDir!.path) {
      _loadFiles(_currentDir!.parent);
    }
  }

  void _navigateToTrash() {
    // Linux trash directory
    final String? home = Platform.environment['HOME'];
    if (home != null) {
      final trashDir = Directory('$home/.local/share/Trash/files');
      if (trashDir.existsSync()) {
        _loadPath(trashDir.path);
      } else {
        // Fallback or show error
      }
    }
  }

  void _handleFileTap(String path) {
    setState(() {
      _selectedFilePaths.clear();
      _selectedFilePaths.add(path);
    });
  }

  void _handleFileDoubleTap(FileSystemEntity entity) {
    if (entity is Directory) {
      _loadFiles(entity);
    }
  }

  // --- UI Widgets ---
  Widget _buildAppBar(ThemeData theme, bool isDesktop) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Iconsax.arrow_up_2),
            onPressed: _navigateToParent,
            color: theme.textTheme.bodyMedium?.color,
            splashRadius: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _BreadcrumbBar(
              path: _currentDir?.path ?? '',
              onPathSelected: _loadPath,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileListView(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final bool showHidden = _hiddenFileVisibility[_currentDir?.path] ?? false;
    final filteredFiles = showHidden
        ? _files
        : _files
              .where((item) => !p.basename(item.entity.path).startsWith('.'))
              .toList();
    if (filteredFiles.isEmpty) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTapDown: (details) =>
            _showBackgroundContextMenu(context, details),
        child: Center(
          child: Text(
            'This directory is empty.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    return GestureDetector(
      onSecondaryTapDown: (details) =>
          _showBackgroundContextMenu(context, details),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: filteredFiles.length,
        itemBuilder: (context, index) {
          final item = filteredFiles[index];
          final isSelected = _selectedFilePaths.contains(item.entity.path);

          return FileListItem(
            key: ValueKey(item.entity.path),
            entity: item.entity,
            stat: item.stat,
            isSelected: isSelected,
            onTap: () => _handleFileTap(item.entity.path),
            onDoubleTap: () => _handleFileDoubleTap(item.entity),
            onSecondaryTapDown: (details) =>
                _showContextMenu(context, details, item),
          );
        },
      ),
    ).animate().fade(duration: 200.ms, curve: Curves.easeIn);
  }

  // (Build method remains the same)
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ResponsiveLayout(
      mobileBody: FrostedGlassCard(
        margin: const EdgeInsets.fromLTRB(8, 40, 8, 8),
        child: Column(
          children: [
            _buildAppBar(theme, false),
            const Divider(height: 1),
            Expanded(child: _buildFileListView(theme)),
          ],
        ),
      ).animate().fade(duration: 500.ms).slideY(begin: 0.1),
      desktopBody: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: _sidebarWidth,
                child: FrostedGlassCard(
                  child: Sidebar(
                    width: _sidebarWidth,
                    onHome: () =>
                        _rootDir != null ? _loadPath(_rootDir!.path) : null,
                    onRoot: () => _loadPath('/'),
                    onTrash: _navigateToTrash,
                    pinnedPaths: _pinnedPaths,
                    onPinTapped: _loadPath,
                  ),
                ),
              ).animate().fade(duration: 500.ms).slideX(begin: -0.1),
              Positioned(
                right: -4,
                top: 0,
                bottom: 0,
                width: 8,
                child: GestureDetector(
                  onHorizontalDragUpdate: _onSidebarResize,
                  child: const MouseRegion(
                    cursor: SystemMouseCursors.resizeLeftRight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child:
                FrostedGlassCard(
                      child: Column(
                        children: [
                          _buildAppBar(theme, true),
                          const Divider(height: 1),
                          Expanded(child: _buildFileListView(theme)),
                        ],
                      ),
                    )
                    .animate()
                    .fade(duration: 500.ms)
                    .slideX(begin: 0.1, delay: 100.ms),
          ),
        ],
      ),
    );
  }
}

// (_BreadcrumbBar class remains the same)
class _BreadcrumbBar extends StatelessWidget {
  final String path;
  final ValueChanged<String> onPathSelected;

  const _BreadcrumbBar({required this.path, required this.onPathSelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = p.split(path);
    if (parts.isEmpty) return const SizedBox.shrink();

    if (parts.length == 1 && parts[0] == '/') {
      return Text('/', style: theme.textTheme.titleMedium);
    }

    final displayParts = parts[0] == '/' ? parts.sublist(1) : parts;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: List.generate(displayParts.length, (index) {
          final part = displayParts[index];
          final isLast = index == displayParts.length - 1;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () {
                  final selectedPath = p.joinAll([
                    '/',
                    ...displayParts.sublist(0, index + 1),
                  ]);
                  onPathSelected(selectedPath);
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Text(
                    part,
                    style: isLast
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.bodyMedium,
                  ),
                ),
              ),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: Icon(
                    Iconsax.arrow_right_3,
                    size: 14,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}
