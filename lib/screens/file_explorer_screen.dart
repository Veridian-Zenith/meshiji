import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path_util;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/file_item.dart';
import '../services/file_operations_service.dart';
import '../services/terminal_service.dart';
import '../utils/app_theme.dart';
import '../widgets/meshiji_ui.dart';
import '../widgets/file_list_builder.dart';
import '../screens/settings/settings_screen.dart';

// Keyboard shortcut intent classes
class _HomeDirectoryIntent extends Intent {}
class _ParentDirectoryIntent extends Intent {}
class _FocusSearchIntent extends Intent {}
class _CopyFilesIntent extends Intent {}
class _PasteFilesIntent extends Intent {}
class _DeleteFilesIntent extends Intent {}
class _ListViewIntent extends Intent {}
class _GridViewIntent extends Intent {}
class _RefreshDirectoryIntent extends Intent {}
class _ToggleTerminalIntent extends Intent {}
class _ClearTerminalIntent extends Intent {}

class FileExplorerScreen extends StatefulWidget {
  const FileExplorerScreen({super.key});

  @override
  State<FileExplorerScreen> createState() => _FileExplorerScreenState();
}

class _FileExplorerScreenState extends State<FileExplorerScreen>
    with TickerProviderStateMixin {
  String _currentPath = '';
  List<FileItem> _files = [];
  List<FileItem> _selectedFiles = [];
  bool _isLoading = true;
  bool _showHidden = false;
  String _searchQuery = '';
  ViewMode _viewMode = ViewMode.list;
  Map<String, String> _folderSizes = {};

  late TabController _tabController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _terminalController = TextEditingController();
  final ScrollController _terminalScrollController = ScrollController();
  final FocusNode _terminalFocusNode = FocusNode();

  bool _terminalVisible = false;
  final List<TerminalCommand> _terminalHistory = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    // Load settings first, then set default directory
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadSettings();
      _navigateToHome();
    });
    _fadeController.forward();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final showHidden = prefs.getBool('showHiddenFiles') ?? false;
    debugPrint('Loading showHidden setting: $showHidden');
    setState(() {
      _showHidden = showHidden;
    });
  }

  Future<void> _saveShowHiddenSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showHiddenFiles', value);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeController.dispose();
    _searchController.dispose();
    _terminalController.dispose();
    _terminalScrollController.dispose();
    _terminalFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadDirectory() async {
    setState(() => _isLoading = true);

    try {
      final directory = Directory(_currentPath);
      // Always list all files (including hidden ones) and filter based on setting
      final entities = await directory.list(recursive: false).toList();

      final files = entities
          .map((entity) => FileItem(entity))
          .where((file) => _showHidden || !file.isHidden)
          .toList();

      // Debug: Log hidden files count
      final hiddenFiles = files.where((file) => file.isHidden).length;
      final totalFiles = files.length;
      debugPrint(
        'Hidden files toggle: $_showHidden, Found $hiddenFiles hidden files out of $totalFiles total',
      );

      files.sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      if (_searchQuery.isNotEmpty) {
        files.retainWhere(
          (file) =>
              file.name.toLowerCase().contains(_searchQuery.toLowerCase()),
        );
      }

      setState(() {
        _files = files;
        _isLoading = false;
      });

      // Calculate folder sizes in the background
      _calculateFolderSizes();
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load directory: $e');
    }
  }

  Future<void> _calculateFolderSizes() async {
    final folderSizes = <String, String>{};

    for (final file in _files) {
      if (file.isDirectory) {
        final size = await file.getFolderSize();
        folderSizes[file.path] = size;
      }
    }

    if (mounted) {
      setState(() {
        _folderSizes = folderSizes;
      });
    }
  }

  void _navigateToDirectory(String path) {
    setState(() {
      _currentPath = path;
      _selectedFiles.clear();
    });
    TerminalService.setCurrentWorkingDirectory(path);
    _loadDirectory();
  }

  void _navigateToParent() {
    final parent = path_util.dirname(_currentPath);
    if (parent != _currentPath) {
      _navigateToDirectory(parent);
    }
  }

  void _navigateToHome() async {
    // Use actual home directory, not documents directory
    final home = Platform.environment['HOME'] ?? '/';
    _navigateToDirectory(home);
  }

  void _toggleFileSelection(FileItem file) {
    setState(() {
      if (_selectedFiles.contains(file)) {
        _selectedFiles.remove(file);
      } else {
        _selectedFiles.add(file);
      }
    });
  }

  void _clearSelection() {
    setState(() => _selectedFiles.clear());
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.accentRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _openFile(FileItem file) async {
    if (file.isDirectory) {
      _navigateToDirectory(file.path);
    } else {
      // Try to open with system default
      try {
        await Process.run('xdg-open', [file.path]);
      } catch (e) {
        _showErrorSnackBar('Failed to open file: $e');
      }
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedFiles.isEmpty) return;

    final confirmed = await _showConfirmationDialog(
      'Move ${_selectedFiles.length} item(s) to trash?',
      'Items will be moved to trash and can be restored later.',
    );

    if (!confirmed) return;

    // Clear folder size cache before file operations
    FileItem.clearFolderSizeCache();

    final result = await FileOperationsService.delete(_selectedFiles, permanent: false);
    if (result.success) {
      _showSuccessSnackBar(result.message!);
      _clearSelection();
      _loadDirectory();
    } else {
      _showErrorSnackBar(result.error!);
    }
  }

  Future<void> _copyFiles() async {
    if (_selectedFiles.isEmpty) return;

    // TODO: Implement copy to clipboard functionality
    _showSuccessSnackBar('Copy functionality coming soon');
  }

  Future<void> _moveFiles() async {
    if (_selectedFiles.isEmpty) return;

    // TODO: Implement move functionality
    _showSuccessSnackBar('Move functionality coming soon');
  }

  Future<void> _renameFile(FileItem file) async {
    final controller = TextEditingController(text: file.name);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => MeshijiDialog(
        title: 'Rename',
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'New name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (result != null && result != file.name) {
      // Clear folder size cache before file operations
      FileItem.clearFolderSizeCache();

      final renameResult = await FileOperationsService.rename(file, result);
      if (renameResult.success) {
        _showSuccessSnackBar(renameResult.message!);
        _loadDirectory();
      } else {
        _showErrorSnackBar(renameResult.error!);
      }
    }
  }

  Future<void> _createNewFolder() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => MeshijiDialog(
        title: 'New Folder',
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Folder name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      // Clear folder size cache before file operations
      FileItem.clearFolderSizeCache();

      final createResult = await FileOperationsService.createDirectory(
        _currentPath,
        result,
      );
      if (createResult.success) {
        _showSuccessSnackBar(createResult.message!);
        _loadDirectory();
      } else {
        _showErrorSnackBar(createResult.error!);
      }
    }
  }

  Future<bool> _showConfirmationDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => MeshijiDialog(
        title: title,
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRed,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _executeTerminalCommand() async {
    final command = _terminalController.text.trim();
    if (command.isEmpty) return;

    final result = await TerminalService.executeCommand(command);
    setState(() {
      _terminalHistory.add(result);
    });

    _terminalController.clear();
    _terminalScrollController.animateTo(
      _terminalScrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  Widget _buildBreadcrumb() {
    final breadcrumbBuilder = BreadcrumbBuilder(
      currentPath: _currentPath,
      onHomeTap: _navigateToHome,
      onParentTap: _navigateToParent,
      onPathTap: _navigateToDirectory,
    );
    return breadcrumbBuilder.build();
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.glassBlack,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryRed.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _createNewFolder,
            icon: const Icon(Icons.create_new_folder, color: Colors.white),
            tooltip: 'New Folder',
          ),
          IconButton(
            onPressed: _selectedFiles.isNotEmpty ? _copyFiles : null,
            icon: const Icon(Icons.copy, color: Colors.white),
            tooltip: 'Copy',
          ),
          IconButton(
            onPressed: _selectedFiles.isNotEmpty ? _moveFiles : null,
            icon: const Icon(Icons.cut, color: Colors.white),
            tooltip: 'Move',
          ),
          IconButton(
            onPressed: _selectedFiles.isNotEmpty ? _deleteSelected : null,
            icon: const Icon(Icons.delete, color: Colors.white),
            tooltip: 'Delete',
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: () async {
              final newValue = !_showHidden;
              setState(() => _showHidden = newValue);
              await _saveShowHiddenSetting(newValue);
              _loadDirectory();
            },
            icon: Icon(
              _showHidden ? Icons.visibility : Icons.visibility_off,
              color: _showHidden ? AppTheme.primaryRed : Colors.white54,
            ),
            tooltip: 'Show Hidden Files',
          ),
          const Spacer(),
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _viewMode = ViewMode.list),
                icon: Icon(
                  Icons.list,
                  color: _viewMode == ViewMode.list
                      ? AppTheme.primaryRed
                      : Colors.white54,
                ),
                tooltip: 'List View',
              ),
              IconButton(
                onPressed: () => setState(() => _viewMode = ViewMode.grid),
                icon: Icon(
                  Icons.grid_view,
                  color: _viewMode == ViewMode.grid
                      ? AppTheme.primaryRed
                      : Colors.white54,
                ),
                tooltip: 'Grid View',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search files...',
          prefixIcon: const Icon(Icons.search, color: AppTheme.primaryRed),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                    _loadDirectory();
                  },
                  icon: const Icon(Icons.clear, color: Colors.white54),
                )
              : null,
          filled: true,
          fillColor: AppTheme.glassBlack,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.primaryRed.withOpacity(0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.primaryRed.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.primaryRed),
          ),
        ),
        style: const TextStyle(color: Colors.white),
        onChanged: (value) {
          setState(() => _searchQuery = value);
          _loadDirectory();
        },
      ),
    );
  }

  Widget _buildFileList() {
    final fileListBuilder = FileListBuilder(
      files: _files,
      selectedFiles: _selectedFiles,
      folderSizes: _folderSizes,
      onFileTap: _openFile,
      onFileSecondaryTap: _showFileContextMenu,
      onToggleSelection: _toggleFileSelection,
      isLoading: _isLoading,
    );

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: _viewMode == ViewMode.list
              ? fileListBuilder.buildListView()
              : fileListBuilder.buildGridView(),
        );
      },
    );
  }

  IconData _getFileIcon(FileItem file) {
    switch (file.type) {
      case 'Text':
        return Icons.description;
      case 'Image':
        return Icons.image;
      case 'Video':
        return Icons.video_file;
      case 'Audio':
        return Icons.audio_file;
      case 'PDF':
        return Icons.picture_as_pdf;
      case 'Archive':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _showFileContextMenu(FileItem file) {
    showDialog(
      context: context,
      builder: (context) => MeshijiDialog(
        title: file.name,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.open_in_new,
                color: AppTheme.primaryRed,
              ),
              title: const Text('Open'),
              onTap: () {
                Navigator.pop(context);
                _openFile(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: AppTheme.primaryRed),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                _renameFile(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: AppTheme.primaryRed),
              title: const Text('Copy'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _selectedFiles = [file];
                });
                _copyFiles();
              },
            ),
            ListTile(
              leading: const Icon(Icons.cut, color: AppTheme.primaryRed),
              title: const Text('Move'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _selectedFiles = [file];
                });
                _moveFiles();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppTheme.primaryRed),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _selectedFiles = [file];
                });
                _deleteSelected();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTerminal() {
    final terminalBuilder = TerminalBuilder(
      history: _terminalHistory,
      controller: _terminalController,
      scrollController: _terminalScrollController,
      focusNode: _terminalFocusNode,
      onCommandSubmit: _executeTerminalCommand,
      onHideTerminal: () => setState(() => _terminalVisible = false),
    );
    return terminalBuilder.build();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        // Navigation shortcuts
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyH): _HomeDirectoryIntent(),
        LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.arrowUp): _ParentDirectoryIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyL): _FocusSearchIntent(),

        // File operations
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyC): _CopyFilesIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyV): _PasteFilesIntent(),
        SingleActivator(LogicalKeyboardKey.delete): _DeleteFilesIntent(),

        // View controls
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit1): _ListViewIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit2): _GridViewIntent(),
        SingleActivator(LogicalKeyboardKey.f5): _RefreshDirectoryIntent(),

        // Terminal shortcuts
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyT): _ToggleTerminalIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK): _ClearTerminalIntent(),
      },
      child: Actions(
        actions: {
          _HomeDirectoryIntent: CallbackAction<_HomeDirectoryIntent>(
            onInvoke: (intent) => _navigateToHome(),
          ),
          _ParentDirectoryIntent: CallbackAction<_ParentDirectoryIntent>(
            onInvoke: (intent) => _navigateToParent(),
          ),
          _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(
            onInvoke: (intent) {
              _searchController.clear();
              setState(() => _searchQuery = '');
              _loadDirectory();
              return null;
            },
          ),
          _CopyFilesIntent: CallbackAction<_CopyFilesIntent>(
            onInvoke: (intent) => _copyFiles(),
          ),
          _PasteFilesIntent: CallbackAction<_PasteFilesIntent>(
            onInvoke: (intent) => _moveFiles(),
          ),
          _DeleteFilesIntent: CallbackAction<_DeleteFilesIntent>(
            onInvoke: (intent) => _deleteSelected(),
          ),
          _ListViewIntent: CallbackAction<_ListViewIntent>(
            onInvoke: (intent) {
              setState(() => _viewMode = ViewMode.list);
              return null;
            },
          ),
          _GridViewIntent: CallbackAction<_GridViewIntent>(
            onInvoke: (intent) {
              setState(() => _viewMode = ViewMode.grid);
              return null;
            },
          ),
          _RefreshDirectoryIntent: CallbackAction<_RefreshDirectoryIntent>(
            onInvoke: (intent) => _loadDirectory(),
          ),
          _ToggleTerminalIntent: CallbackAction<_ToggleTerminalIntent>(
            onInvoke: (intent) {
              setState(() => _terminalVisible = !_terminalVisible);
              return null;
            },
          ),
          _ClearTerminalIntent: CallbackAction<_ClearTerminalIntent>(
            onInvoke: (intent) {
              setState(() {
                _terminalHistory.clear();
              });
              return null;
            },
          ),
        },
        child: Scaffold(
          backgroundColor: AppTheme.backgroundBlack,
          appBar: AppBar(
            title: const Text(
              'Meshiji',
              style: TextStyle(
                color: AppTheme.primaryRed,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
                },
                icon: const Icon(Icons.settings, color: AppTheme.primaryRed),
                tooltip: 'Settings',
              ),
              IconButton(
                onPressed: () =>
                    setState(() => _terminalVisible = !_terminalVisible),
                icon: Icon(
                  _terminalVisible ? Icons.keyboard_arrow_down : Icons.terminal,
                  color: _terminalVisible ? Colors.white : AppTheme.primaryRed,
                ),
                tooltip: 'Terminal',
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildBreadcrumb(),
                    const SizedBox(height: 12),
                    _buildToolbar(),
                    const SizedBox(height: 12),
                    _buildSearchBar(),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.glassBlack,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryRed.withOpacity(0.3)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _buildFileList(),
                  ),
                ),
              ),
              if (_terminalVisible) _buildTerminal(),
            ],
          ),
          floatingActionButton: _selectedFiles.isNotEmpty
              ? Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryRed,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryRed.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Text(
                    '${_selectedFiles.length} selected',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

enum ViewMode { list, grid }
