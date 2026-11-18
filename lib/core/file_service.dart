import 'dart:io';

/// Linux file operations — abstracts HOME/XDG paths; keeps freedom from UI.
class FileOperationService {
  static Future<void> copy(String src, String dst) => File(src).copy(dst);
  static Future<void> rename(String oldPath, String newPath) => File(oldPath).rename(newPath);
  static Future<List<FileSystemEntity>> listDir(String path) => Directory(path).list().toList();
  static Future<File> createFile(String path) => File(path).create();
  static Future<void> paste() async { /* buffer -> target; implement when buffer service exists */ }
  // Paste, cut, progress hooks to follow — currently TBD in UI.
}
class FileBufferService {
  static final List<String> _buffer = [];
  static bool get hasBuffer => _buffer.isNotEmpty;
  static void copy(String p) => _buffer.add(p);
  static void clear() => _buffer.clear();
  static List<String> get buffer => List.unmodifiable(_buffer);
}
