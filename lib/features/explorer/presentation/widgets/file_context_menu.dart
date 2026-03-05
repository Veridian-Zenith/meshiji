import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:meshiji/shared/widgets/frosted_glass.dart';
import 'package:meshiji/theme/tokens/design_tokens.dart';

class FileContextMenu extends StatelessWidget {
  final FileSystemEntity entity;
  final bool isPinned;
  final VoidCallback onOpen;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;
  final VoidCallback onDismiss;

  const FileContextMenu({
    super.key,
    required this.entity,
    required this.isPinned,
    required this.onOpen,
    required this.onTogglePin,
    required this.onDelete,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDir = entity is Directory;
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 250,
        child: FrostedGlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isDir)
                ListTile(
                  leading: Icon(
                    isPinned ? Iconsax.location_slash : Iconsax.location,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                  title: Text(isPinned ? 'Unpin from Sidebar' : 'Pin to Sidebar'),
                  onTap: () {
                    onDismiss();
                    onTogglePin();
                  },
                ),
              if (isDir) const Divider(height: 1),
              ListTile(
                leading: const Icon(Iconsax.folder_open),
                title: const Text('Open'),
                onTap: () {
                  onDismiss();
                  onOpen();
                },
              ),
              const Divider(height: 1),
              // --- TBD: File Explorer Operations ---
              // ListTile(leading: const Icon(Iconsax.copy), title: const Text('Copy'), onTap: () {}),
              // ListTile(leading: const Icon(Iconsax.scissor), title: const Text('Cut'), onTap: () {}),
              // ListTile(leading: const Icon(Iconsax.edit), title: const Text('Rename'), onTap: () {}),
              // const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Iconsax.trash,
                  color: DesignTokens.accentDanger,
                ),
                title: const Text('Delete'),
                iconColor: DesignTokens.accentDanger,
                textColor: DesignTokens.accentDanger,
                onTap: () {
                  onDismiss();
                  onDelete();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
