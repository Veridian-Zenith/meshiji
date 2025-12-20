import 'dart:io';

class TerminalCommand {
  final String command;
  final String arguments;
  final DateTime timestamp;
  final String output;
  final String? error;
  final int exitCode;

  TerminalCommand({
    required this.command,
    this.arguments = '',
    required this.timestamp,
    required this.output,
    this.error,
    required this.exitCode,
  });

  Map<String, dynamic> toMap() {
    return {
      'command': command,
      'arguments': arguments,
      'timestamp': timestamp.toIso8601String(),
      'output': output,
      'error': error,
      'exitCode': exitCode,
    };
  }
}

class TerminalService {
  static String? _currentWorkingDirectory;
  static final List<TerminalCommand> _history = [];
  static final List<String> _commandHistory = [];
  static int _historyIndex = -1;

  static String? get currentWorkingDirectory => _currentWorkingDirectory;
  static List<TerminalCommand> get history => List.unmodifiable(_history);
  static List<String> get commandHistory => List.unmodifiable(_commandHistory);

  static Future<TerminalCommand> executeCommand(String command, {String? workingDirectory}) async {
    final timestamp = DateTime.now();
    final args = _parseCommand(command);

    try {
      // Handle built-in commands
      if (args.isNotEmpty) {
        switch (args[0]) {
          case 'cd':
            return await _handleCd(args.skip(1).join(' '), timestamp);
          case 'pwd':
            return _handlePwd(timestamp);
          case 'clear':
            return _handleClear(timestamp);
          case 'history':
            return _handleHistory(timestamp);
          case 'help':
            return _handleHelp(timestamp);
          case 'ls':
            return await _handleLs(args.skip(1).join(' '), timestamp);
          case 'mkdir':
            return await _handleMkdir(args.skip(1).join(' '), timestamp);
          case 'touch':
            return await _handleTouch(args.skip(1).join(' '), timestamp);
          case 'rm':
            return await _handleRm(args.skip(1).join(' '), timestamp);
          case 'cp':
            return await _handleCp(args.skip(1).join(' '), timestamp);
          case 'mv':
            return await _handleMv(args.skip(1).join(' '), timestamp);
          case 'exit':
            return _handleExit(timestamp);
        }
      }

      // Execute external command
      final result = await Process.run(
        args[0],
        args.skip(1).toList(),
        workingDirectory: workingDirectory ?? _currentWorkingDirectory,
      );

      final commandResult = TerminalCommand(
        command: args[0],
        arguments: args.skip(1).join(' '),
        timestamp: timestamp,
        output: result.stdout as String? ?? '',
        error: result.stderr as String?,
        exitCode: result.exitCode,
      );

      _addToHistory(commandResult);
      return commandResult;

    } catch (e) {
      final errorResult = TerminalCommand(
        command: args.isNotEmpty ? args[0] : 'unknown',
        arguments: args.skip(1).join(' '),
        timestamp: timestamp,
        output: '',
        error: e.toString(),
        exitCode: 1,
      );

      _addToHistory(errorResult);
      return errorResult;
    }
  }

  static List<String> _parseCommand(String command) {
    // Simple command parser - split by whitespace but handle quoted strings
    final List<String> args = [];
    bool inQuotes = false;
    String currentArg = '';
    String quoteChar = '';

    for (int i = 0; i < command.length; i++) {
      final char = command[i];

      if ((char == '"' || char == "'") && !inQuotes) {
        // Start of quoted string
        inQuotes = true;
        quoteChar = char;
      } else if (char == quoteChar && inQuotes) {
        // End of quoted string
        inQuotes = false;
        quoteChar = '';
        if (currentArg.isNotEmpty) {
          args.add(currentArg);
          currentArg = '';
        }
      } else if (char == ' ' && !inQuotes) {
        // Whitespace separator
        if (currentArg.isNotEmpty) {
          args.add(currentArg);
          currentArg = '';
        }
      } else {
        // Regular character
        currentArg += char;
      }
    }

    // Add the last argument if any
    if (currentArg.isNotEmpty) {
      args.add(currentArg);
    }

    // If no arguments were parsed, return the whole command as a single argument
    return args.isNotEmpty ? args : [command.trim()];
  }

  static Future<TerminalCommand> _handleCd(String path, DateTime timestamp) async {
    try {
      if (path.isEmpty || path == '~') {
        path = Platform.environment['HOME'] ?? '/';
      } else if (path.startsWith('~/')) {
        final home = Platform.environment['HOME'] ?? '/';
        path = '$home${path.substring(1)}';
      }

      final dir = Directory(path);
      if (await dir.exists()) {
        _currentWorkingDirectory = dir.absolute.path;
        final result = TerminalCommand(
          command: 'cd',
          arguments: path,
          timestamp: timestamp,
          output: '',
          exitCode: 0,
        );
        _addToHistory(result);
        return result;
      } else {
        final result = TerminalCommand(
          command: 'cd',
          arguments: path,
          timestamp: timestamp,
          output: '',
          error: 'Directory not found: $path',
          exitCode: 1,
        );
        _addToHistory(result);
        return result;
      }
    } catch (e) {
      final result = TerminalCommand(
        command: 'cd',
        arguments: path,
        timestamp: timestamp,
        output: '',
        error: e.toString(),
        exitCode: 1,
      );
      _addToHistory(result);
      return result;
    }
  }

  static TerminalCommand _handlePwd(DateTime timestamp) {
    final result = TerminalCommand(
      command: 'pwd',
      timestamp: timestamp,
      output: _currentWorkingDirectory ?? Directory.current.path,
      exitCode: 0,
    );
    _addToHistory(result);
    return result;
  }

  static TerminalCommand _handleClear(DateTime timestamp) {
    _history.clear();
    return TerminalCommand(
      command: 'clear',
      timestamp: timestamp,
      output: '',
      exitCode: 0,
    );
  }

  static TerminalCommand _handleHistory(DateTime timestamp) {
    final output = _commandHistory.asMap().entries.map((entry) =>
      '${entry.key.toString().padLeft(4)}: ${entry.value}'
    ).join('\n');

    final result = TerminalCommand(
      command: 'history',
      timestamp: timestamp,
      output: output,
      exitCode: 0,
    );
    _addToHistory(result);
    return result;
  }

  static TerminalCommand _handleHelp(DateTime timestamp) {
    final helpText = '''Meshiji Terminal Commands:
========================
Built-in Commands:
  cd [path]       - Change directory
  pwd             - Print working directory
  clear           - Clear terminal history
  history         - Show command history
  help            - Show this help message
  ls [options]    - List directory contents
  mkdir <name>    - Create directory
  touch <name>    - Create empty file
  rm <path>       - Remove file or directory
  cp <src> <dst>  - Copy file or directory
  mv <src> <dst>  - Move/rename file or directory
  exit            - Exit terminal

External Commands:
  Any system command available in PATH''';

    final result = TerminalCommand(
      command: 'help',
      timestamp: timestamp,
      output: helpText,
      exitCode: 0,
    );
    _addToHistory(result);
    return result;
  }

  static Future<TerminalCommand> _handleLs(String options, DateTime timestamp) async {
    try {
      final dir = Directory(_currentWorkingDirectory ?? Directory.current.path);
      final entities = await dir.list().toList();

      String output = '';
      final showHidden = options.contains('-a') || options.contains('--all');

      for (final entity in entities) {
        final name = entity.path.split(Platform.pathSeparator).last;
        if (!showHidden && name.startsWith('.')) continue;

        final prefix = entity is Directory ? '📁' : '📄';
        output += '$prefix $name\n';
      }

      final result = TerminalCommand(
        command: 'ls',
        arguments: options,
        timestamp: timestamp,
        output: output.trim(),
        exitCode: 0,
      );
      _addToHistory(result);
      return result;
    } catch (e) {
      final result = TerminalCommand(
        command: 'ls',
        arguments: options,
        timestamp: timestamp,
        output: '',
        error: e.toString(),
        exitCode: 1,
      );
      _addToHistory(result);
      return result;
    }
  }

  static Future<TerminalCommand> _handleMkdir(String name, DateTime timestamp) async {
    try {
      if (name.isEmpty) {
        throw Exception('mkdir: missing operand');
      }

      final dir = Directory(name);
      if (!name.startsWith('/')) {
        final fullPath = '${_currentWorkingDirectory ?? Directory.current.path}/$name';
        await Directory(fullPath).create(recursive: true);
      } else {
        await dir.create(recursive: true);
      }

      final result = TerminalCommand(
        command: 'mkdir',
        arguments: name,
        timestamp: timestamp,
        output: '',
        exitCode: 0,
      );
      _addToHistory(result);
      return result;
    } catch (e) {
      final result = TerminalCommand(
        command: 'mkdir',
        arguments: name,
        timestamp: timestamp,
        output: '',
        error: e.toString(),
        exitCode: 1,
      );
      _addToHistory(result);
      return result;
    }
  }

  static Future<TerminalCommand> _handleTouch(String name, DateTime timestamp) async {
    try {
      if (name.isEmpty) {
        throw Exception('touch: missing file operand');
      }

      final file = File(name);
      if (!name.startsWith('/')) {
        final fullPath = '${_currentWorkingDirectory ?? Directory.current.path}/$name';
        await File(fullPath).create();
      } else {
        await file.create();
      }

      final result = TerminalCommand(
        command: 'touch',
        arguments: name,
        timestamp: timestamp,
        output: '',
        exitCode: 0,
      );
      _addToHistory(result);
      return result;
    } catch (e) {
      final result = TerminalCommand(
        command: 'touch',
        arguments: name,
        timestamp: timestamp,
        output: '',
        error: e.toString(),
        exitCode: 1,
      );
      _addToHistory(result);
      return result;
    }
  }

  static Future<TerminalCommand> _handleRm(String path, DateTime timestamp) async {
    try {
      if (path.isEmpty) {
        throw Exception('rm: missing operand');
      }

      final fullPath = path.startsWith('/')
          ? path
          : '${_currentWorkingDirectory ?? Directory.current.path}/$path';

      final entity = FileSystemEntity.isDirectorySync(fullPath)
          ? Directory(fullPath)
          : File(fullPath);

      if (entity is Directory) {
        await entity.delete(recursive: true);
      } else {
        await entity.delete();
      }

      final result = TerminalCommand(
        command: 'rm',
        arguments: path,
        timestamp: timestamp,
        output: '',
        exitCode: 0,
      );
      _addToHistory(result);
      return result;
    } catch (e) {
      final result = TerminalCommand(
        command: 'rm',
        arguments: path,
        timestamp: timestamp,
        output: '',
        error: e.toString(),
        exitCode: 1,
      );
      _addToHistory(result);
      return result;
    }
  }

  static Future<TerminalCommand> _handleCp(String args, DateTime timestamp) async {
    try {
      final parts = args.split(' ');
      if (parts.length < 2) {
        throw Exception('cp: missing file operand');
      }

      final src = parts[0];
      final dst = parts[1];

      final srcPath = src.startsWith('/')
          ? src
          : '${_currentWorkingDirectory ?? Directory.current.path}/$src';
      final dstPath = dst.startsWith('/')
          ? dst
          : '${_currentWorkingDirectory ?? Directory.current.path}/$dst';

      final srcEntity = FileSystemEntity.isDirectorySync(srcPath)
          ? Directory(srcPath)
          : File(srcPath);

      if (srcEntity is Directory) {
        await _copyDirectory(Directory(srcPath), Directory(dstPath));
      } else {
        await File(srcPath).copy(dstPath);
      }

      final result = TerminalCommand(
        command: 'cp',
        arguments: args,
        timestamp: timestamp,
        output: '',
        exitCode: 0,
      );
      _addToHistory(result);
      return result;
    } catch (e) {
      final result = TerminalCommand(
        command: 'cp',
        arguments: args,
        timestamp: timestamp,
        output: '',
        error: e.toString(),
        exitCode: 1,
      );
      _addToHistory(result);
      return result;
    }
  }

  static Future<TerminalCommand> _handleMv(String args, DateTime timestamp) async {
    try {
      final parts = args.split(' ');
      if (parts.length < 2) {
        throw Exception('mv: missing file operand');
      }

      final src = parts[0];
      final dst = parts[1];

      final srcPath = src.startsWith('/')
          ? src
          : '${_currentWorkingDirectory ?? Directory.current.path}/$src';
      final dstPath = dst.startsWith('/')
          ? dst
          : '${_currentWorkingDirectory ?? Directory.current.path}/$dst';

      final entity = FileSystemEntity.isDirectorySync(srcPath)
          ? Directory(srcPath)
          : File(srcPath);

      await entity.rename(dstPath);

      final result = TerminalCommand(
        command: 'mv',
        arguments: args,
        timestamp: timestamp,
        output: '',
        exitCode: 0,
      );
      _addToHistory(result);
      return result;
    } catch (e) {
      final result = TerminalCommand(
        command: 'mv',
        arguments: args,
        timestamp: timestamp,
        output: '',
        error: e.toString(),
        exitCode: 1,
      );
      _addToHistory(result);
      return result;
    }
  }

  static TerminalCommand _handleExit(DateTime timestamp) {
    final result = TerminalCommand(
      command: 'exit',
      timestamp: timestamp,
      output: 'Terminal session ended',
      exitCode: 0,
    );
    _addToHistory(result);
    return result;
  }

  static Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);

    await for (final entity in source.list()) {
      final newPath = '${destination.path}/${entity.path.split(Platform.pathSeparator).last}';

      if (entity is File) {
        await entity.copy(newPath);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(newPath));
      }
    }
  }

  static void _addToHistory(TerminalCommand command) {
    _history.add(command);

    final fullCommand = command.arguments.isNotEmpty
        ? '${command.command} ${command.arguments}'
        : command.command;

    if (_commandHistory.isEmpty || _commandHistory.last != fullCommand) {
      _commandHistory.add(fullCommand);
      _historyIndex = _commandHistory.length - 1;
    }

    // Keep history manageable
    if (_history.length > 1000) {
      _history.removeAt(0);
    }
    if (_commandHistory.length > 500) {
      _commandHistory.removeAt(0);
    }
  }

  static void setCurrentWorkingDirectory(String path) {
    _currentWorkingDirectory = path;
  }

  static String? getPreviousCommand() {
    if (_historyIndex > 0) {
      _historyIndex--;
      return _commandHistory[_historyIndex];
    }
    return null;
  }

  static String? getNextCommand() {
    if (_historyIndex < _commandHistory.length - 1) {
      _historyIndex++;
      return _commandHistory[_historyIndex];
    }
    return null;
  }

  static void resetHistoryIndex() {
    _historyIndex = _commandHistory.length;
  }
}
