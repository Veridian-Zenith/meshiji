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

  static Future<void> restoreFromTrash(String trashedPath) async {
    await init();

    final basename = p.basename(trashedPath);
    final infoFilePath = p.join(_infoDirPath, '$basename.trashinfo');

    if (!File(trashedPath).existsSync() || !File(infoFilePath).existsSync()) {
      debugPrint('Trash item or info file not found for: $trashedPath');
      return;
    }

    try {
      final infoContent = await File(infoFilePath).readAsString();
      final lines = infoContent.split('\n');
      String? originalPath;
      for (final line in lines) {
        if (line.startsWith('Path=')) {
          originalPath = line.substring('Path='.length);
          break;
        }
      }

      if (originalPath == null) {
        debugPrint('Original path not found in info file for: $trashedPath');
        return;
      }

      final originalFile = File(originalPath);
      final originalDirectory = Directory(originalPath);

      // Ensure the original directory exists before restoring
      if (!originalFile.parent.existsSync() && !originalDirectory.parent.existsSync()) {
        await originalFile.parent.create(recursive: true);
      }

      await File(trashedPath).rename(originalPath);
      await File(infoFilePath).delete();
      debugPrint('Restored "$trashedPath" to "$originalPath"');
    } catch (e) {
      debugPrint('Error restoring "$trashedPath" from trash: $e');
      rethrow;
    }
  }

  static Future<void> deletePermanently(String trashedPath) async {
    await init();

    final basename = p.basename(trashedPath);
    final infoFilePath = p.join(_infoDirPath, '$basename.trashinfo');

    try {
      if (File(trashedPath).existsSync()) {
        await File(trashedPath).delete(recursive: true);
      }
      if (File(infoFilePath).existsSync()) {
        await File(infoFilePath).delete();
      }
      debugPrint('Permanently deleted "$trashedPath"');
    } catch (e) {
      debugPrint('Error permanently deleting "$trashedPath": $e');
      rethrow;
    }
  }
}
