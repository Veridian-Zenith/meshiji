import 'dart:io';
class SearchService {
  static Future<List<FileSystemEntity>> recursive(String root, String query) async => Directory(root).list(recursive: true).where((e) => e.path.contains(query)).toList();
}
