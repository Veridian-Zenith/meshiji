import 'dart:io';
// Linux only: sort by name/date/size/type ascending/descending
class SortService {
  static List<FileSystemEntity> byName(List<FileSystemEntity> list, {bool asc = true}) => [...list]..sort((a,b)=>asc?a.path.compareTo(b.path):b.path.compareTo(a.path));
}
