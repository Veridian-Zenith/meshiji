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
      for (final item in items) {
        if (item.isDirectory) {
          await Directory(item.path).delete(recursive: true);
        } else {
          await File(item.path).delete();
        }
      }

      return FileOperationsResult.success('Deleted ${items.length} item(s)');
    } catch (e) {
      return FileOperationsResult.error('Failed to delete: ${e.toString()}');
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
