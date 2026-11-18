import 'package:flutter/material.dart';

/// Progress overlay — lives in UI layer, not service.
Future<void> showProgressOverlay(BuildContext c, Future<void> op) async {
  showDialog(context: c, barrierDismissible: false,
    builder: (_) => AlertDialog(content: Row(children: [CircularProgressIndicator(), SizedBox(width: 16), Text('Working...')])));
  await op;
  if (c.mounted && Navigator.of(c).canPop()) Navigator.of(c).pop();
}
