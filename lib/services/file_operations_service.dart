import 'dart:io';
import 'package:path/path.dart' as path_util;
import '../models/file_item.dart';

class FileOperationsResult {
  final bool success;
  final String? error;
  final String? message;

  FileOperationsResult({required this.success, this.error, this.message});

  factory FileOperationsResult.success(String message) {
    return FileOperationsResult(success: true, message: message);
  }

  factory FileOperationsResult.error(String error) {
    return FileOperationsResult(success: false, error: error);
  }
}

class FileOperationsService {
  static Future<FileOperationsResult> copy(
    List<FileItem> items,
    String destinationPath,
  ) async {
    try {
      final destinationDir = Directory(destinationPath);
      if (!await destinationDir.exists()) {
        await destinationDir.create(recursive: true);
      }

      for (final item in items) {
        final destination = path_util.join(
          destinationPath,
          path_util.basename(item.path),
        );

        if (item.isDirectory) {
          await _copyDirectory(Directory(item.path), Directory(destination));
        } else {
          await File(item.path).copy(destination);
        }
      }

      return FileOperationsResult.success(
        'Copied ${items.length} item(s) to $destinationPath',
      );
    } catch (e) {
      return FileOperationsResult.error('Failed to copy: ${e.toString()}');
    }
  }

  static Future<void> _copyDirectory(
    Directory source,
    Directory destination,
  ) async {
    await destination.create(recursive: true);

    await for (final entity in source.list()) {
      final newPath = path_util.join(
        destination.path,
        path_util.basename(entity.path),
      );

      if (entity is File) {
        await entity.copy(newPath);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(newPath));
      }
    }
  }

  static Future<FileOperationsResult> move(
    List<FileItem> items,
    String destinationPath,
  ) async {
    try {
      final destinationDir = Directory(destinationPath);
      if (!await destinationDir.exists()) {
        await destinationDir.create(recursive: true);
      }

      for (final item in items) {
        final destination = path_util.join(
          destinationPath,
          path_util.basename(item.path),
        );

        if (item.isDirectory) {
          await Directory(item.path).rename(destination);
        } else {
          await File(item.path).rename(destination);
        }
      }

      return FileOperationsResult.success(
        'Moved ${items.length} item(s) to $destinationPath',
      );
    } catch (e) {
      return FileOperationsResult.error('Failed to move: ${e.toString()}');
    }
  }

  static Future<FileOperationsResult> delete(
    List<FileItem> items, {
    bool permanent = false,
  }) async {
    try {
      if (permanent) {
        // Permanent deletion
        for (final item in items) {
          if (item.isDirectory) {
            await Directory(item.path).delete(recursive: true);
          } else {
            await File(item.path).delete();
          }
        }
        return FileOperationsResult.success('Permanently deleted ${items.length} item(s)');
      } else {
        // Move to trash/recycle bin
        final trashPath = await _getTrashPath();
        final movedItems = <String>[];

        for (final item in items) {
          try {
            final trashItemPath = await _getTrashItemPath(trashPath, item);
            if (item.isDirectory) {
              await Directory(item.path).rename(trashItemPath);
            } else {
              await File(item.path).rename(trashItemPath);
            }
            movedItems.add(item.name);
          } catch (e) {
            return FileOperationsResult.error('Failed to move ${item.name} to trash: ${e.toString()}');
          }
        }

        return FileOperationsResult.success('Moved ${movedItems.length} item(s) to trash');
      }
    } catch (e) {
      return FileOperationsResult.error('Failed to delete: ${e.toString()}');
    }
  }

  static Future<String> _getTrashPath() async {
    final homeDir = Platform.environment['HOME'] ?? '/';
    final trashDir = '$homeDir/.local/share/Trash/files';
    final infoDir = '$homeDir/.local/share/Trash/info';

    // Create both trash directories if they don't exist
    await Directory(trashDir).create(recursive: true);
    await Directory(infoDir).create(recursive: true);

    return trashDir;
  }

  static Future<String> _getTrashItemPath(String trashPath, FileItem item) async {
    final fileName = item.name;
    final fileExtension = item.extension ?? '';
    final baseName = fileExtension.isNotEmpty
        ? fileName.substring(0, fileName.length - fileExtension.length - 1)
        : fileName;

    // Check if file with same name already exists in trash
    var counter = 0;
    var trashItemPath = '$trashPath/$fileName';

    while (await File(trashItemPath).exists() || await Directory(trashItemPath).exists()) {
      counter++;
      trashItemPath = fileExtension.isNotEmpty
          ? '$trashPath/${baseName}_$counter$fileExtension'
          : '$trashPath/${fileName}_$counter';
    }

    return trashItemPath;
  }

  static Future<FileOperationsResult> emptyTrash() async {
    try {
      final trashPath = await _getTrashPath();
      final trashDir = Directory(trashPath);

      if (await trashDir.exists()) {
        await trashDir.delete(recursive: true);
        await _getTrashPath(); // Recreate trash directory
        return FileOperationsResult.success('Trash emptied successfully');
      } else {
        return FileOperationsResult.success('Trash is already empty');
      }
    } catch (e) {
      return FileOperationsResult.error('Failed to empty trash: ${e.toString()}');
    }
  }

  static Future<FileOperationsResult> restoreFromTrash(String trashItemPath, String restorePath) async {
    try {
      if (!await FileSystemEntity.exists(trashItemPath)) {
        return FileOperationsResult.error('Item not found in trash');
      }

      final fileName = trashItemPath.split('/').last;
      final restoreFilePath = '$restorePath/$fileName';

      // Check if file already exists at restore location
      if (await FileSystemEntity.exists(restoreFilePath)) {
        return FileOperationsResult.error('A file with this name already exists at the restore location');
      }

      await File(trashItemPath).rename(restoreFilePath);
      return FileOperationsResult.success('Item restored successfully');
    } catch (e) {
      return FileOperationsResult.error('Failed to restore item: ${e.toString()}');
    }
  }

  static Future<List<String>> getTrashContents() async {
    try {
      final trashPath = await _getTrashPath();
      final trashDir = Directory(trashPath);

      if (!await trashDir.exists()) {
        return [];
      }

      final List<String> items = [];
      await for (final entity in trashDir.list()) {
        items.add(entity.path);
      }

      return items;
    } catch (e) {
      return [];
    }
  }

  static Future<FileOperationsResult> rename(
    FileItem item,
    String newName,
  ) async {
    try {
      final parentDir = path_util.dirname(item.path);
      final newPath = path_util.join(parentDir, newName);

      if (await File(newPath).exists() || await Directory(newPath).exists()) {
        return FileOperationsResult.error(
          'An item with that name already exists',
        );
      }

      if (item.isDirectory) {
        await Directory(item.path).rename(newPath);
      } else {
        await File(item.path).rename(newPath);
      }

      return FileOperationsResult.success('Renamed to $newName');
    } catch (e) {
      return FileOperationsResult.error('Failed to rename: ${e.toString()}');
    }
  }

  static Future<FileOperationsResult> createDirectory(
    String parentPath,
    String name,
  ) async {
    try {
      final newPath = path_util.join(parentPath, name);

      if (await Directory(newPath).exists()) {
        return FileOperationsResult.error('Directory already exists');
      }

      await Directory(newPath).create(recursive: true);
      return FileOperationsResult.success('Created directory: $name');
    } catch (e) {
      return FileOperationsResult.error(
        'Failed to create directory: ${e.toString()}',
      );
    }
  }

  static Future<FileOperationsResult> createFile(
    String parentPath,
    String name,
  ) async {
    try {
      final newPath = path_util.join(parentPath, name);

      if (await File(newPath).exists()) {
        return FileOperationsResult.error('File already exists');
      }

      await File(newPath).create();
      return FileOperationsResult.success('Created file: $name');
    } catch (e) {
      return FileOperationsResult.error(
        'Failed to create file: ${e.toString()}',
      );
    }
  }

  static Future<int> calculateDirectorySize(Directory directory) async {
    int totalSize = 0;

    try {
      await for (final entity in directory.list()) {
        if (entity is File) {
          totalSize += await entity.length();
        } else if (entity is Directory) {
          totalSize += await calculateDirectorySize(entity);
        }
      }
    } catch (e) {
      // Skip files we can't access
    }

    return totalSize;
  }

  static Future<bool> hasWritePermission(String path) async {
    try {
      final testFile = File(path_util.join(path, '.meshiji_write_test'));
      await testFile.create();
      await testFile.delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, String>> getFileChecksums(String filePath) async {
    final Map<String, String> checksums = {};

    try {
      // Note: For SHA checksums, you'd need to add crypto package
      // For now, just return basic info
      final file = File(filePath);
      final stat = await file.stat();

      checksums['size'] = stat.size.toString();
      checksums['modified'] = stat.modified.toIso8601String();
      checksums['type'] = stat.type.toString();
    } catch (e) {
      checksums['error'] = e.toString();
    }

    return checksums;
  }
}
