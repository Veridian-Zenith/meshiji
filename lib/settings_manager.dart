import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart'; // For debugPrint

class SettingsManager {
  // Lazy initialization: we use HOME or fallback to /home/dae
  static final String _defaultHome = Platform.environment['HOME'] ?? '/home/dae';
  final String _settingsFilePath = p.join(_defaultHome, '.config', 'meshiji', 'settings.json');

  // Internal settings map
  Map<String, dynamic> _settings = {};

  // Public getter
  Map<String, dynamic> get settings => _settings;

  /// Load settings from disk or create default if missing/corrupted
  Future<void> loadSettings() async {
    final settingsFile = File(_settingsFilePath);

    if (!settingsFile.existsSync()) {
      // File doesn't exist → create default
      _settings = _defaultSettings();
      await _saveSettingsToFile();
      return;
    }

    try {
      final content = await settingsFile.readAsString();
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        // Merge with defaults to ensure all keys are present
        _settings = _defaultSettings()..addAll(decoded);
      } else {
        debugPrint('Settings file malformed, resetting to defaults.');
        _settings = _defaultSettings();
        await _saveSettingsToFile();
      }
    } catch (e) {
      debugPrint('Error loading settings from $_settingsFilePath: $e');
      _settings = _defaultSettings();
      await _saveSettingsToFile();
    }
  }

  /// Save settings to disk
  Future<void> saveSettings({
    bool? autoCompute,
    bool? lowSpec,
    bool? pluginsEnabled,
    bool? pluginProcessIsolation,
    int? concurrency,
    bool? builtInTerminalEnabled,
    bool? luaPluginSupportEnabled,
  }) async {
    if (autoCompute != null) _settings['autoCompute'] = autoCompute;
    if (lowSpec != null) _settings['lowSpec'] = lowSpec;
    if (pluginsEnabled != null) _settings['pluginsEnabled'] = pluginsEnabled;
    if (pluginProcessIsolation != null) _settings['pluginProcessIsolation'] = pluginProcessIsolation;
    if (concurrency != null) _settings['concurrency'] = concurrency;
    if (builtInTerminalEnabled != null) _settings['builtInTerminalEnabled'] = builtInTerminalEnabled;
    if (luaPluginSupportEnabled != null) _settings['luaPluginSupportEnabled'] = luaPluginSupportEnabled;

    await _saveSettingsToFile();
  }

  /// Internal: default settings map
  Map<String, dynamic> _defaultSettings() {
    return {
      'autoCompute': true,
      'lowSpec': false,
      'pluginsEnabled': false,
      'pluginProcessIsolation': false,
      'concurrency': 2, // Default to 2, as no specific value was provided.
      'builtInTerminalEnabled': false,
      'luaPluginSupportEnabled': false,
    };
  }

  /// Internal: save current settings to disk
  Future<void> _saveSettingsToFile() async {
    try {
      final settingsFile = File(_settingsFilePath);
      if (!settingsFile.parent.existsSync()) {
        settingsFile.parent.createSync(recursive: true);
      }
      await settingsFile.writeAsString(JsonEncoder.withIndent('  ').convert(_settings));
    } catch (e) {
      debugPrint('Error saving settings to $_settingsFilePath: $e');
    }
  }
}
