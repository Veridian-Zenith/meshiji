import 'package:flutter/material.dart';
import 'package:path/path.dart' as path_util;
import '../models/file_item.dart';
import '../utils/app_theme.dart';
import '../services/terminal_service.dart';

class FileListBuilder {
  final List<FileItem> files;
  final List<FileItem> selectedFiles;
  final Map<String, String> folderSizes;
  final Function(FileItem) onFileTap;
  final Function(FileItem) onFileSecondaryTap;
  final Function(FileItem) onToggleSelection;
  final bool isLoading;

  FileListBuilder({
    required this.files,
    required this.selectedFiles,
    required this.folderSizes,
    required this.onFileTap,
    required this.onFileSecondaryTap,
    required this.onToggleSelection,
    required this.isLoading,
  });

  Widget buildListView() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryRed),
      );
    }

    if (files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              'This folder is empty',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        final isSelected = selectedFiles.contains(file);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Material(
            color: isSelected
                ? AppTheme.primaryRed.withOpacity(0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onFileTap(file),
              onSecondaryTap: () => onFileSecondaryTap(file),
              child: ListTile(
                leading: Icon(
                  file.isDirectory ? Icons.folder : _getFileIcon(file),
                  color: isSelected ? Colors.white : AppTheme.primaryRed,
                  size: 28,
                ),
                title: Text(
                  file.name,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  file.isDirectory
                      ? 'Folder • ${folderSizes[file.path] ?? 'Calculating...'}'
                      : '${file.type} • ${file.formattedSize}',
                  style: TextStyle(
                    color: isSelected ? Colors.white70 : Colors.white54,
                    fontSize: 12,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      file.modified != null ? _formatDate(file.modified!) : '',
                      style: TextStyle(
                        color: isSelected ? Colors.white70 : Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Checkbox(
                      value: isSelected,
                      onChanged: (value) => onToggleSelection(file),
                      activeColor: AppTheme.primaryRed,
                      checkColor: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildGridView() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryRed),
      );
    }

    if (files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              'This folder is empty',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        final isSelected = selectedFiles.contains(file);

        return GestureDetector(
          onTap: () => onFileTap(file),
          onSecondaryTap: () => onFileSecondaryTap(file),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryRed.withOpacity(0.2)
                  : AppTheme.glassBlack,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppTheme.primaryRed
                    : AppTheme.primaryRed.withOpacity(0.3),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  file.isDirectory ? Icons.folder : _getFileIcon(file),
                  color: isSelected ? Colors.white : AppTheme.primaryRed,
                  size: 48,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    file.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    color: AppTheme.primaryRed,
                    size: 16,
                  ),
              ],
            ),
          ),
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
}

class BreadcrumbBuilder {
  final String currentPath;
  final Function() onHomeTap;
  final Function() onParentTap;
  final Function(String) onPathTap;

  BreadcrumbBuilder({
    required this.currentPath,
    required this.onHomeTap,
    required this.onParentTap,
    required this.onPathTap,
  });

  Widget build() {
    final parts = currentPath.split('/');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.glassBlack,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryRed.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onHomeTap,
            icon: const Icon(Icons.home, color: AppTheme.primaryRed),
            tooltip: 'Home',
          ),
          IconButton(
            onPressed: onParentTap,
            icon: const Icon(Icons.arrow_upward, color: AppTheme.primaryRed),
            tooltip: 'Parent Directory',
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => onPathTap('/'),
                    child: const Text(
                      '/',
                      style: TextStyle(color: AppTheme.primaryRed),
                    ),
                  ),
                  ...parts.asMap().entries.map((entry) {
                    if (entry.key == 0 && entry.value.isEmpty) {
                      return const SizedBox();
                    }
                    final isLast = entry.key == parts.length - 1;
                    final currentPath = parts
                        .sublist(0, entry.key + 1)
                        .join('/');

                    return Row(
                      children: [
                        const Text(
                          ' / ',
                          style: TextStyle(color: Colors.white54),
                        ),
                        if (isLast)
                          Text(
                            entry.value,
                            style: const TextStyle(color: Colors.white),
                          )
                        else
                          TextButton(
                            onPressed: () => onPathTap(currentPath),
                            child: Text(
                              entry.value,
                              style: const TextStyle(
                                color: AppTheme.primaryRed,
                              ),
                            ),
                          ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TerminalBuilder {
  final List<TerminalCommand> history;
  final TextEditingController controller;
  final ScrollController scrollController;
  final FocusNode focusNode;
  final Function() onCommandSubmit;
  final Function() onHideTerminal;

  TerminalBuilder({
    required this.history,
    required this.controller,
    required this.scrollController,
    required this.focusNode,
    required this.onCommandSubmit,
    required this.onHideTerminal,
  });

  Widget build() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border.all(color: AppTheme.primaryRed.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.glassBlack,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(color: AppTheme.primaryRed.withOpacity(0.3)),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.terminal, color: AppTheme.primaryRed),
                const SizedBox(width: 8),
                const Text(
                  'Terminal',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onHideTerminal,
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white54,
                  ),
                  tooltip: 'Hide Terminal',
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              child: ListView.builder(
                controller: scrollController,
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final command = history[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryRed.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '\$ ${command.command} ${command.arguments}',
                                style: const TextStyle(
                                  color: AppTheme.primaryRed,
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (command.output.isNotEmpty)
                          Text(
                            command.output,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        if (command.error != null)
                          Text(
                            command.error!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppTheme.primaryRed.withOpacity(0.3)),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  '\$',
                  style: TextStyle(
                    color: AppTheme.primaryRed,
                    fontFamily: 'monospace',
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Enter command...',
                      hintStyle: TextStyle(
                        color: Colors.white54,
                        fontFamily: 'monospace',
                      ),
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                    onSubmitted: (_) => onCommandSubmit(),
                  ),
                ),
                IconButton(
                  onPressed: onCommandSubmit,
                  icon: const Icon(Icons.send, color: AppTheme.primaryRed),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
