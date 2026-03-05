import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:meshiji/theme/tokens/design_tokens.dart';
import 'package:path/path.dart' as p;

class FileListItem extends StatelessWidget {
  final FileSystemEntity entity;
  final FileStat stat;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final Function(TapDownDetails) onSecondaryTapDown;

  const FileListItem({
    super.key,
    required this.entity,
    required this.stat,
    required this.isSelected,
    required this.onTap,
    required this.onDoubleTap,
    required this.onSecondaryTapDown,
  });

  IconData _getIconForEntity() {
    if (entity is Directory) {
      return Iconsax.folder;
    }
    final path = entity.path.toLowerCase();
    if (path.endsWith('.zip') ||
        path.endsWith('.tar') ||
        path.endsWith('.gz')) {
      return Iconsax.archive_1;
    }
    if (path.endsWith('.jpg') ||
        path.endsWith('.png') ||
        path.endsWith('.gif')) {
      return Iconsax.gallery;
    }
    if (path.endsWith('.pdf')) return Iconsax.document;
    if (path.endsWith('.txt')) return Iconsax.document_text;
    return Iconsax.document_normal;
  }

  String _getMetadata() {
    // Stat is already calculated in the background isolate,
    // but NumberFormat and DateFormat are quite heavy when instantiated thousands of times.
    // However, for ListView.builder they only run for visible items, so this is generally okay.
    // If it lags here, we'd move this formatting into the isolate as well.
    final size = stat.size < 1024
        ? '${stat.size} B'
        : stat.size < 1024 * 1024
        ? '${(stat.size / 1024).toStringAsFixed(1)} KB'
        : '${(stat.size / (1024 * 1024)).toStringAsFixed(1)} MB';

    final modified = DateFormat.yMMMd().format(stat.modified);
    return '$size  •  $modified';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDirectory = entity is Directory;

    final bgColor = isSelected
        ? DesignTokens.selectionOverlay.withAlpha(60)
        : Colors.transparent;

    return GestureDetector(
      onSecondaryTapDown: onSecondaryTapDown,
      child: InkWell(
        onTapDown: (_) => onTap(),
        onTap:
            () {}, // Empty but required to enable the InkWell's ripple and hover effects
        onDoubleTap: onDoubleTap,
        onLongPress: () {
          // Provides a consistent way to open the context menu on mobile.
          final RenderBox overlay =
              Overlay.of(context).context.findRenderObject() as RenderBox;
          final details = TapDownDetails(
            globalPosition: overlay.globalToLocal(const Offset(0, 0)),
          );
          onSecondaryTapDown(details);
        },
        borderRadius: BorderRadius.circular(DesignTokens.radiusBase),
        splashColor: DesignTokens.selectionOverlay.withAlpha(80),
        highlightColor: DesignTokens.selectionOverlay.withAlpha(40),
        // Use InkWell's built-in hover color for simplicity and reliability.
        hoverColor: DesignTokens.selectionOverlay.withAlpha(20),
        child: Container(
          // Using static Container instead of AnimatedContainer for list scroll performance
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(DesignTokens.radiusBase),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              Icon(
                _getIconForEntity(),
                color: isDirectory
                    ? theme.colorScheme.primary
                    : DesignTokens.textSecondary,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.basename(
                        entity.path,
                      ), // Use path package for safer filename extraction.
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getMetadata(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: DesignTokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (isDirectory)
                Icon(
                  Iconsax.arrow_right_3,
                  color: DesignTokens.textMuted,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
