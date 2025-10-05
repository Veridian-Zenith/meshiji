import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum LogLevel {
  debug(0, '🐛'),
  info(1, 'ℹ️'),
  warning(2, '⚠️'),
  error(3, '❌');

  const LogLevel(this.level, this.emoji);
  final int level;
  final String emoji;
}

class Logger {
  static Logger? _instance;
  static Logger get instance => _instance ??= Logger._internal();

  Logger._internal() {
    _initLogFile();
  }

  static const int _maxLogFiles = 5;
  static const int _maxLogSize = 10 * 1024 * 1024; // 10MB per file

  File? _logFile;
  bool _enableFileLogging = true;
  LogLevel _minLevel = kDebugMode ? LogLevel.debug : LogLevel.info;

  Future<void> _initLogFile() async {
    try {
      if (!_enableFileLogging) return;

      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/logs');

      // Create logs directory if it doesn't exist
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
        Logger.instance.debug('Created logs directory: ${logDir.path}');
      }

      // Clean up old log files
      await _cleanupOldLogs(logDir);

      // Create new log file with timestamp
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('T', '_');
      _logFile = File('${logDir.path}/meshiji_$timestamp.log');

      // Write header with more detailed info
      await _logFile!.writeAsString(
        '=== Meshiji File Explorer Log Started ===\n'
        'Timestamp: ${DateTime.now()}\n'
        'Platform: ${Platform.operatingSystem} (${Platform.version})\n'
        'Version: 1.0.0\n'
        'Dart SDK: ${Platform.version}\n'
        'Log Level: ${_minLevel.name}\n'
        '\n',
        mode: FileMode.write,
      );

      Logger.instance.info('Log file initialized successfully: ${_logFile!.path}');
    } catch (e) {
      print('Failed to initialize log file: $e');
      _enableFileLogging = false;
      Logger.instance.warning('File logging disabled due to initialization error', e);
    }
  }

  Future<void> _cleanupOldLogs(Directory logDir) async {
    try {
      final files = await logDir.list().toList();
      final logFiles = files.whereType<File>().where((f) => f.path.endsWith('.log')).toList();

      if (logFiles.length >= _maxLogFiles) {
        // Sort by modification time, keep newest
        logFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

        // Delete oldest files
        for (var i = _maxLogFiles - 1; i < logFiles.length; i++) {
          await logFiles[i].delete();
        }
      }

      // Check if current log file is too large
      if (_logFile != null && await _logFile!.exists()) {
        final size = await _logFile!.length();
        if (size > _maxLogSize) {
          // Rotate log file
          final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
          final newFile = File('${logDir.path}/meshiji_$timestamp.log');
          await _logFile!.rename(newFile.path);
          _logFile = newFile;
        }
      }
    } catch (e) {
      print('Failed to cleanup logs: $e');
    }
  }

  void setMinLevel(LogLevel level) {
    _minLevel = level;
  }

  void debug(String message, [Object? data]) {
    _log(LogLevel.debug, message, data);
  }

  void info(String message, [Object? data]) {
    _log(LogLevel.info, message, data);
  }

  void warning(String message, [Object? data]) {
    _log(LogLevel.warning, message, data);
  }

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.error, message, error, stackTrace);
  }

  void _log(LogLevel level, String message, [Object? data, StackTrace? stackTrace]) {
    if (level.level < _minLevel.level) return;

    final timestamp = DateTime.now().toString();
    final logMessage = '${level.emoji} [$timestamp] $message';

    // Console output (always enabled)
    print(logMessage);
    if (data != null) print('  Data: $data');
    if (stackTrace != null) print('  StackTrace: $stackTrace');

    // File output (if enabled)
    if (_enableFileLogging && _logFile != null) {
      _writeToFile('$logMessage\n');
      if (data != null) _writeToFile('  Data: $data\n');
      if (stackTrace != null) _writeToFile('  StackTrace: $stackTrace\n');
    }
  }

  Future<void> _writeToFile(String content) async {
    if (_logFile == null) return;

    try {
      await _logFile!.writeAsString(content, mode: FileMode.append);
    } catch (e) {
      print('Failed to write to log file: $e');
    }
  }

  Future<String?> getLogContent() async {
    if (_logFile != null && await _logFile!.exists()) {
      return await _logFile!.readAsString();
    }
    return null;
  }

  Future<List<File>> getLogFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/logs');
      if (!await logDir.exists()) return [];

      final files = await logDir.list().toList();
      return files.whereType<File>().where((f) => f.path.endsWith('.log')).toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    } catch (e) {
      return [];
    }
  }
}
