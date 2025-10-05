import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:path/path.dart' as p;
import 'size_cache.dart';
import 'trash_manager.dart';
import 'app_theme.dart';
import 'logger.dart';

class FileTile extends StatefulWidget {
  final String name;
  final String path;
  final bool isDirectory;
  final VoidCallback? onTap;
  final VoidCallback? onCreateFolder;
  final bool isTrashDirectory; // New: indicates if the current directory is trash
  final ValueChanged<String>? onRestore; // New: callback for restoring from trash
  final ValueChanged<String>? onDeletePermanently; // New: callback for permanent delete

  const FileTile({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.onTap,
    this.onCreateFolder,
    this.isTrashDirectory = false, // Default to false
    this.onRestore,
    this.onDeletePermanently,
    super.key,
  });

  @override
  State<FileTile> createState() => _FileTileState();
}

class _FileTileState extends State<FileTile> {
  bool _hovering = false;
  String _meta = '';
  bool _computingFolderSize = false;

  Future<void> _maybeComputeFolderSize() async {
    if (!widget.isDirectory) return;

    setState(() => _computingFolderSize = true);
    Logger.instance.debug('Computing size for folder: ${widget.path}');

    SizeCache.instance.requestSize(widget.path, (size) {
      try {
        final sizeText = _readableFileSize(size);
        if (mounted) {
          setState(() => _meta = '$sizeText • Folder');
          Logger.instance.debug('Computed size for ${widget.path}: $sizeText');
        }
      } catch (e) {
        Logger.instance.warning('Error formatting size for ${widget.path}: $e');
        if (mounted) setState(() => _meta = 'Folder');
      } finally {
        if (mounted) setState(() => _computingFolderSize = false);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  void _loadMeta() {
    try {
      final isDir = FileSystemEntity.isDirectorySync(widget.path);
      if (isDir) {
        // For directories, start with placeholder and compute size
        _meta = 'Computing...';
        _maybeComputeFolderSize();
      } else {
        // For files, get size and modified date immediately
        final file = File(widget.path);
        final stat = file.statSync();
        final size = stat.size;
        final modified = stat.modified;
        final sizeText = _readableFileSize(size);
        _meta = '$sizeText • ${_shortDate(modified)}';
      }
    } catch (e) {
      Logger.instance.error('Error loading metadata for ${widget.path}', e);
      _meta = 'Error loading info';
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
    final borderColor = _hovering ? AppTheme.goldAccent : AppTheme.gold;
  final shadowColor = Color.fromRGBO(255, 215, 0, _hovering ? 0.14 : 0.06);

    final content = GestureDetector(
      onSecondaryTapDown: (details) {
        _showContextMenu(context, details.globalPosition);
      },
      child: Material(
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
                    color: AppTheme.goldAccent,
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
                          color: AppTheme.gold,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_meta.isNotEmpty) const SizedBox(height: 4),
                      if (_computingFolderSize)
                        const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(AppTheme.gold))),
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
                // No PopupMenuButton here, handled by GestureDetector
              ],
            ),
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
      onSecondaryTapDown: (details) {
        _showContextMenu(context, details.globalPosition);
      },
      child: decorated,
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40), // smaller rect, the touch area
        Offset.zero & MediaQuery.of(context).size, // container rect
      ),
      items: [
        PopupMenuItem<String>(value: 'open', child: Text('Open', style: TextStyle(color: AppTheme.gold))),
        PopupMenuItem<String>(value: 'reveal', child: Text('Reveal in file manager', style: TextStyle(color: AppTheme.gold))),
        if (!widget.isTrashDirectory)
          PopupMenuItem<String>(value: 'new_folder', child: Text('New Folder', style: TextStyle(color: AppTheme.gold))),
        if (widget.isTrashDirectory) ...[
          PopupMenuItem<String>(value: 'restore', child: Text('Restore', style: TextStyle(color: AppTheme.gold))),
          PopupMenuItem<String>(value: 'delete_permanently', child: Text('Delete Permanently', style: TextStyle(color: Colors.redAccent))),
        ] else ...[
          PopupMenuItem<String>(value: 'delete', child: Text('Move to Trash', style: TextStyle(color: Colors.redAccent))),
        ],
      ],
      color: Colors.black,
    ).then((value) async {
      if (value == null) return;

      if (value == 'open' && widget.isDirectory) {
        widget.onTap?.call();
      } else if (value == 'new_folder') {
        widget.onCreateFolder?.call();
      } else if (value == 'reveal') {
        try {
          String? errorMessage;
          if (defaultTargetPlatform == TargetPlatform.linux) {
            // Try multiple Linux file managers
            final result = await Process.run('xdg-open', [p.dirname(widget.path)]);
            if (result.exitCode != 0) {
              errorMessage = 'Failed to open file manager: ${result.stderr}';
            }
          } else if (defaultTargetPlatform == TargetPlatform.windows) {
            final result = await Process.run('explorer', [p.dirname(widget.path)]);
            if (result.exitCode != 0) {
              errorMessage = 'Failed to open explorer: ${result.stderr}';
            }
          } else if (defaultTargetPlatform == TargetPlatform.macOS) {
            final result = await Process.run('open', [p.dirname(widget.path)]);
            if (result.exitCode != 0) {
              errorMessage = 'Failed to open finder: ${result.stderr}';
            }
          }

          if (errorMessage != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage, style: const TextStyle(color: AppTheme.gold)),
                backgroundColor: Colors.black,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error opening file manager: $e', style: const TextStyle(color: AppTheme.gold)),
                backgroundColor: Colors.black,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } else if (value == 'delete') {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.black,
            title: const Text('Confirm Delete', style: TextStyle(color: AppTheme.gold)),
            content: Text('Are you sure you want to move "${widget.name}" to trash?', style: const TextStyle(color: AppTheme.gold)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel', style: TextStyle(color: AppTheme.goldAccent)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Move to Trash', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        );

        if (confirm == true) {
          try {
            await TrashManager.moveToTrash(widget.path);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Moved to trash', style: TextStyle(color: AppTheme.gold)),
                  backgroundColor: Colors.black,
                  duration: Duration(seconds: 2),
                ),
              );
              // Trigger refresh in parent
              // We need to call a callback to refresh the file list
              // For now, we'll use Navigator.pop to close any dialogs
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to move to trash: $e', style: const TextStyle(color: AppTheme.gold)),
                  backgroundColor: Colors.black,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          }
        }
      } else if (value == 'restore') {
        widget.onRestore?.call(widget.path);
      } else if (value == 'delete_permanently') {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.black,
            title: const Text('Confirm Permanent Delete', style: TextStyle(color: AppTheme.gold)),
            content: Text('Are you sure you want to permanently delete "${widget.name}"? This cannot be undone.', style: const TextStyle(color: AppTheme.gold)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel', style: TextStyle(color: AppTheme.goldAccent)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete Permanently', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        );

        if (confirm == true) {
          widget.onDeletePermanently?.call(widget.path);
        }
      }
    });
  }
}
