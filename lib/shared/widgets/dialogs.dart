import 'package:flutter/material.dart';
import 'package:meshiji/shared/widgets/frosted_glass.dart';
import 'package:meshiji/theme/tokens/design_tokens.dart';

Future<bool?> showDeleteConfirmationDialog(
  BuildContext context,
  int itemCount,
) {
  final theme = Theme.of(context);
  final String title = 'Delete ${itemCount > 1 ? "$itemCount items" : "item"}?';
  const String content = 'This action cannot be undone.';

  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withAlpha(100),
    builder: (BuildContext context) {
      return BackdropFilter(
        filter: const ColorFilter.mode(Colors.black, BlendMode.dstATop),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: FrostedGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(content, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        child: const Text('Cancel'),
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: DesignTokens.accentDanger,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Delete'),
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ],
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
