import 'dart:io';
import 'package:path/path.dart' as path_util;

class FileItem {
  final FileSystemEntity entity;
  late final String name;
  late final String path;
  late final bool isDirectory;
  late final int? size;
  late final DateTime? modified;
  late final DateTime? accessed;
  late final int? mode;
  late final String? extension;
  late final bool isHidden;

  FileItem(this.entity) {
    path = entity.path;
    name = path_util.basename(entity.path);
    isDirectory = entity is Directory;
    size = entity is File ? (entity as File).lengthSync() : null;
    modified = entity.statSync().modified;
    accessed = entity.statSync().accessed;
    mode = entity.statSync().mode;
    extension = entity is File ? path_util.extension(entity.path) : null;
    isHidden = name.startsWith('.');
  }

  String get formattedSize {
    if (size == null) return 'Directory';
    if (size! <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = (size! > 0 ? (size! / 1024).floor() : 0);
    while (i >= suffixes.length - 1) {
      i--;
    }
    return '${(size! / (1 << (10 * i))).toStringAsFixed(1)} ${suffixes[i]}';
  }

  // Calculate folder size with proper size ranges and caching
  static final Map<String, String> _folderSizeCache = {};

  Future<String> getFolderSize() async {
    if (!isDirectory) return formattedSize;

    // Check cache first
    if (_folderSizeCache.containsKey(path)) {
      return _folderSizeCache[path]!;
    }

    try {
      final dir = Directory(path);
      int totalSize = 0;
      const maxSize = 20 * 1024 * 1024 * 1024; // 20 GiB

      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          final fileSize = await entity.length();
          totalSize += fileSize;

          // Stop if we exceed 20 GiB
          if (totalSize >= maxSize) {
            final result = '> 20 GiB';
            _folderSizeCache[path] = result;
            return result;
          }
        }
      }

      if (totalSize <= 0) {
        final result = 'Empty';
        _folderSizeCache[path] = result;
        return result;
      }

      // Use proper size ranges from KB to GB
      const suffixes = ['B', 'KB', 'MB', 'GB'];
      var size = totalSize.toDouble();
      var i = 0;

      while (size >= 1024 && i < suffixes.length - 1) {
        size /= 1024;
        i++;
      }

      final result =
          '${size.toStringAsFixed(size < 10 ? 2 : 1)} ${suffixes[i]}';
      _folderSizeCache[path] = result;
      return result;
    } catch (e) {
      return 'Directory';
    }
  }

  // Clear cache (useful when files are modified)
  static void clearFolderSizeCache() {
    _folderSizeCache.clear();
  }

  String get type {
    if (isDirectory) return 'Directory';
    if (extension == null) return 'File';

    switch (extension!.toLowerCase()) {
      case '.txt':
      case '.md':
      case '.json':
      case '.yaml':
      case '.yml':
        return 'Text';
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
      case '.bmp':
      case '.svg':
        return 'Image';
      case '.mp4':
      case '.avi':
      case '.mkv':
      case '.mov':
      case '.wmv':
        return 'Video';
      case '.mp3':
      case '.wav':
      case '.flac':
      case '.aac':
      case '.ogg':
        return 'Audio';
      case '.pdf':
        return 'PDF';
      case '.zip':
      case '.rar':
      case '.7z':
      case '.tar':
      case '.gz':
        return 'Archive';
      default:
        return 'File';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'path': path,
      'isDirectory': isDirectory,
      'size': size,
      'modified': modified?.toIso8601String(),
      'accessed': accessed?.toIso8601String(),
      'mode': mode?.toString(),
      'extension': extension,
      'isHidden': isHidden,
      'type': type,
    };
  }
}
