import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:meshiji/shared/widgets/frosted_glass.dart';
import 'package:meshiji/theme/tokens/design_tokens.dart';

class DirectoryContextMenu extends StatelessWidget {
  final bool showHidden;
  final bool canPaste;
  final VoidCallback onToggleHidden;
  final VoidCallback onNewFolder;
  final VoidCallback onNewFile;
  final VoidCallback onPaste;
  final VoidCallback onDismiss;

  const DirectoryContextMenu({
    super.key,
    required this.showHidden,
    required this.canPaste,
    required this.onToggleHidden,
    required this.onNewFolder,
    required this.onNewFile,
    required this.onPaste,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 250,
        child: FrostedGlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Iconsax.folder_add),
                title: const Text('New Folder'),
                onTap: () {
                  onDismiss();
                  onNewFolder();
                },
              ),
              ListTile(
                leading: const Icon(Iconsax.document_1),
                title: const Text('New File'),
                onTap: () {
                  onDismiss();
                  onNewFile();
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  Iconsax.clipboard_text,
                  color: canPaste ? null : DesignTokens.textMuted,
                ),
                title: Text(
                  'Paste',
                  style: TextStyle(
                    color: canPaste ? null : DesignTokens.textMuted,
                  ),
                ),
                enabled: canPaste,
                onTap: canPaste
                    ? () {
                        onDismiss();
                        onPaste();
                      }
                    : null,
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(showHidden ? Iconsax.eye_slash : Iconsax.eye),
                title: Text(showHidden ? 'Hide Hidden Files' : 'Show Hidden Files'),
                onTap: () {
                  onDismiss();
                  onToggleHidden();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
