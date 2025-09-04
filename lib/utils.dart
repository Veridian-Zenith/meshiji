import 'dart:io';
import 'package:path/path.dart' as p;

String getUserHomeDirectory() {
  final home = Platform.environment['HOME'];
  if (home != null && home.isNotEmpty) {
    return home;
  }
  // Fallback for other platforms or if HOME is not set
  if (Platform.isWindows) {
    return Platform.environment['USERPROFILE'] ?? p.current;
  }
  return p.current; // Default to current directory if home cannot be determined
}
