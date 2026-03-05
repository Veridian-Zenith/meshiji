import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:meshiji/theme/tokens/design_tokens.dart';
import 'package:path/path.dart' as p;

class Sidebar extends StatelessWidget {
  final double width;
  final VoidCallback onHome;
  final VoidCallback onRoot;
  final VoidCallback onTrash;
  final List<String> pinnedPaths;
  final ValueChanged<String> onPinTapped;

  const Sidebar({
    super.key,
    this.width = 250.0,
    required this.onHome,
    required this.onRoot,
    required this.onTrash,
    required this.pinnedPaths,
    required this.onPinTapped,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: ListView(
        padding: const EdgeInsets.all(DesignTokens.spacingBase),
        children: [
          _SidebarItem(icon: Iconsax.home_2, text: 'Home', onTap: onHome),
          _SidebarItem(icon: Iconsax.driver, text: 'Root', onTap: onRoot),
          const Divider(height: 32),
          if (pinnedPaths.isNotEmpty) ...[
            ...pinnedPaths.map(
              (path) => _SidebarItem(
                icon: Iconsax.folder_open,
                text: p.basename(path),
                onTap: () => onPinTapped(path),
              ),
            ),
            const Divider(height: 32),
          ],
          _SidebarItem(
            icon: Iconsax.trash,
            text: 'Trash',
            onTap: onTrash,
            iconColor: DesignTokens.accentDanger,
            textColor: DesignTokens.accentDanger,
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;

  const _SidebarItem({
    required this.icon,
    required this.text,
    required this.onTap,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 22, color: iconColor),
      title: Text(text),
      textColor: textColor,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
