import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart'; // For debugPrint

class TrashManager {
  static final String _trashDirPath = p.join(Platform.environment['HOME']!, '.local', 'share', 'Trash');
  static final String _filesDirPath = p.join(_trashDirPath, 'files');
  static final String _infoDirPath = p.join(_trashDirPath, 'info');

  static Future<void> init() async {
    final trashDir = Directory(_trashDirPath);
    if (!trashDir.existsSync()) {
      await trashDir.create(recursive: true);
    }
    final filesDir = Directory(_filesDirPath);
    if (!filesDir.existsSync()) {
      await filesDir.create(recursive: true);
    }
    final infoDir = Directory(_infoDirPath);
    if (!infoDir.existsSync()) {
      await infoDir.create(recursive: true);
    }
  }

  static Future<void> moveToTrash(String path) async {
    final file = File(path);
    final directory = Directory(path);

    if (!file.existsSync() && !directory.existsSync()) {
      debugPrint('File or directory not found: $path');
      return;
    }

    await init(); // Ensure trash directories exist

    final basename = p.basename(path);
    final timestamp = DateTime.now().toUtc().toIso8601String().replaceAll(RegExp(r'[^0-9T]'), '');
    final trashedFileName = '$basename.$timestamp';
    final destinationPath = p.join(_filesDirPath, trashedFileName);
    final infoFilePath = p.join(_infoDirPath, '$trashedFileName.trashinfo');

    try {
      if (file.existsSync()) {
        await file.rename(destinationPath);
      } else if (directory.existsSync()) {
        await directory.rename(destinationPath);
      }

      // Create .trashinfo file
      final trashInfoContent = '''
[Trash Info]
Path=${Uri.file(path).toFilePath()}
DeletionDate=${DateTime.now().toUtc().toIso8601String()}
''';
      await File(infoFilePath).writeAsString(trashInfoContent);
      debugPrint('Moved "$path" to trash as "$destinationPath"');
    } catch (e) {
      debugPrint('Error moving "$path" to trash: $e');
      rethrow; // Re-throw to indicate failure
    }
  }
}
