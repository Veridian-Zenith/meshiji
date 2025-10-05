import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'utils.dart';
import 'app_theme.dart';

class ExplorerHome extends StatefulWidget {
  const ExplorerHome({super.key, required this.title});
  final String title;

  @override
  State<ExplorerHome> createState() => ExplorerHomeState();
}

class ExplorerHomeState extends State<ExplorerHome> {
  Directory currentDir = Directory.current;
  List<FileSystemEntity> files = [];
  bool isLoading = true;
  String query = '';
  Timer? searchTimer;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  void _loadFiles() {
    setState(() => isLoading = true);
    try {
      final items = currentDir.listSync();
      final filtered = query.isEmpty
          ? items
          : items.where((e) => p.basename(e.path).toLowerCase().contains(query.toLowerCase())).toList();

      // Sort: directories first, then by name
      filtered.sort((a, b) {
        final aIsDir = FileSystemEntity.isDirectorySync(a.path);
        final bIsDir = FileSystemEntity.isDirectorySync(b.path);
        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;
        return p.basename(a.path).compareTo(p.basename(b.path));
      });

      setState(() {
        files = filtered;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        files = [];
        isLoading = false;
      });
    }
  }

  void _goToDir(Directory dir) {
    if (dir.existsSync()) {
      setState(() => currentDir = dir);
      _loadFiles();
    }
  }

  void _goUp() {
    if (currentDir.parent.path != currentDir.path) {
      _goToDir(currentDir.parent);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: Text(
          currentDir.path,
          style: const TextStyle(color: AppTheme.gold, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_upward, color: AppTheme.gold),
          onPressed: _goUp,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.gold),
            onPressed: _loadFiles,
          ),
          IconButton(
            icon: const Icon(Icons.create_new_folder, color: AppTheme.gold),
            onPressed: () async {
              final name = await _showCreateFolderDialog();
              if (name != null && name.isNotEmpty) {
                try {
                  await Directory(p.join(currentDir.path, name)).create();
                  _loadFiles();
                } catch (e) {
                  _showError('Failed to create folder: $e');
                }
              }
            },
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: AppTheme.surface,
        child: ListView(
          children: [
            Container(
              height: 80,
              decoration: const BoxDecoration(color: AppTheme.background),
              child: const Center(
                child: Text('Navigation', style: TextStyle(color: AppTheme.gold, fontSize: 18)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home, color: AppTheme.gold),
              title: const Text('Home', style: TextStyle(color: AppTheme.gold)),
              onTap: () {
                _goToDir(Directory(getUserHomeDirectory()));
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder, color: AppTheme.gold),
              title: const Text('Documents', style: TextStyle(color: AppTheme.gold)),
              onTap: () {
                _goToDir(Directory(p.join(getUserHomeDirectory(), 'Documents')));
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download, color: AppTheme.gold),
              title: const Text('Downloads', style: TextStyle(color: AppTheme.gold)),
              onTap: () {
                _goToDir(Directory(p.join(getUserHomeDirectory(), 'Downloads')));
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.surface,
            child: TextField(
              onChanged: (value) {
                searchTimer?.cancel();
                searchTimer = Timer(const Duration(milliseconds: 300), () {
                  setState(() => query = value);
                  _loadFiles();
                });
              },
              style: const TextStyle(color: AppTheme.gold),
              decoration: InputDecoration(
                hintText: 'Search files...',
                hintStyle: const TextStyle(color: AppTheme.gold),
                prefixIcon: const Icon(Icons.search, color: AppTheme.gold),
                filled: true,
                fillColor: AppTheme.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.gold),
                ),
              ),
            ),
          ),
          // File list
          Expanded(
            child: Container(
              color: AppTheme.background,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.gold)))
                  : ListView.builder(
                      itemCount: files.length,
                      itemBuilder: (context, index) {
                        final entity = files[index];
                        final name = p.basename(entity.path);
                        final isDir = FileSystemEntity.isDirectorySync(entity.path);

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDir ? AppTheme.surface : AppTheme.background,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppTheme.gold.withOpacity(0.2)),
                          ),
                          child: ListTile(
                            leading: Icon(
                              isDir ? Icons.folder : Icons.insert_drive_file,
                              color: AppTheme.gold,
                            ),
                            title: Text(name, style: const TextStyle(color: AppTheme.gold)),
                            onTap: isDir ? () => _goToDir(Directory(entity.path)) : null,
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _showCreateFolderDialog() {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Create New Folder', style: TextStyle(color: AppTheme.gold)),
        content: TextField(
          autofocus: true,
          style: const TextStyle(color: AppTheme.gold),
          decoration: const InputDecoration(
            hintText: 'Folder Name',
            hintStyle: TextStyle(color: AppTheme.gold),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.gold)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text('Create', style: TextStyle(color: AppTheme.gold)),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: AppTheme.gold)),
        backgroundColor: AppTheme.background,
      ),
    );
  }
}
