import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'utils.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

// A class to represent a single plugin.
class Plugin {
  final PluginManifest manifest;
  final String luaScriptPath; // Path to the Lua script
  Plugin(this.manifest, this.luaScriptPath);
}

// A class to hold metadata about a plugin.
class PluginManifest {
  final String name;
  final String author;
  final String version;
  final String description;
  final String script; // Name of the Lua script file

  PluginManifest({
    required this.name,
    required this.author,
    required this.version,
    required this.description,
    required this.script,
  });

  factory PluginManifest.fromJson(Map<String, dynamic> json) {
    return PluginManifest(
      name: json['name'] as String,
      author: json['author'] as String,
      version: json['version'] as String,
      description: json['description'] as String,
      script: json['script'] as String,
    );
  }
}

// A class to manage the loading and lifecycle of plugins.
class PluginManager {
  final List<Plugin> _plugins = [];
  final String _pluginsDirPath = p.join(getUserHomeDirectory(), '.config', 'meshiji', 'plugins');

  List<Plugin> get plugins => _plugins;

  Future<void> loadPlugins() async {
    _plugins.clear();
    final pluginsDir = Directory(_pluginsDirPath);
    if (!pluginsDir.existsSync()) {
      pluginsDir.createSync(recursive: true);
      return;
    }

    for (final entity in pluginsDir.listSync()) {
      if (entity is Directory) {
        final manifestFile = File(p.join(entity.path, 'plugin.json'));
        if (manifestFile.existsSync()) {
          try {
            final content = await manifestFile.readAsString();
            final json = jsonDecode(content) as Map<String, dynamic>;
            final manifest = PluginManifest.fromJson(json);
            final luaScriptPath = p.join(entity.path, manifest.script);
            if (File(luaScriptPath).existsSync()) {
              _plugins.add(Plugin(manifest, luaScriptPath));
            }
          } catch (e) {
            debugPrint('Error loading plugin manifest from ${manifestFile.path}: $e');
          }
        }
      }
    }
    debugPrint('Loaded ${_plugins.length} plugins.');
  }
}
