import 'package:flutter/material.dart';
import 'settings_manager.dart';
import 'size_cache.dart';
import 'app_theme.dart';
import 'explorer_home.dart';

// Refactored to a StatefulWidget for better state management and performance.
class SettingsDialog extends StatefulWidget {
  final SettingsManager settingsManager;
  final ExplorerHomeState explorerState;
  final bool initialPluginsEnabled;
  final bool initialPluginProcessIsolation;
  final int initialConcurrency;
  final bool initialBuiltInTerminalEnabled;
  final bool initialLuaPluginSupportEnabled;

  const SettingsDialog({
    required this.settingsManager,
    required this.explorerState,
    required this.initialPluginsEnabled,
    required this.initialPluginProcessIsolation,
    required this.initialConcurrency,
    required this.initialBuiltInTerminalEnabled,
    required this.initialLuaPluginSupportEnabled,
    Key? key,
  }) : super(key: key);

  @override
  _SettingsDialogState createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late bool _pluginsEnabled;
  late bool _pluginProcessIsolation;
  late int _concurrency;
  late bool _builtInTerminalEnabled;
  late bool _luaPluginSupportEnabled;

  @override
  void initState() {
    super.initState();
    _pluginsEnabled = widget.initialPluginsEnabled;
    _pluginProcessIsolation = widget.initialPluginProcessIsolation;
    _concurrency = widget.initialConcurrency;
    _builtInTerminalEnabled = widget.initialBuiltInTerminalEnabled;
    _luaPluginSupportEnabled = widget.initialLuaPluginSupportEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Settings', style: TextStyle(color: AppTheme.gold, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            const Text('Performance', style: TextStyle(color: AppTheme.gold, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('- Auto compute folder sizes: toggled from main UI', style: TextStyle(color: AppTheme.gold)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Concurrency (1-8)', style: TextStyle(color: AppTheme.gold)),
                DropdownButton<int>(
                  dropdownColor: Colors.black,
                  value: _concurrency,
                  items: List.generate(8, (index) => index + 1)
                      .map((e) => DropdownMenuItem(value: e, child: Text('$e', style: const TextStyle(color: AppTheme.gold))))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _concurrency = v);
                      widget.settingsManager.saveSettings(concurrency: v);
                      SizeCache.instance.setConcurrency(v);
                    }
                  },
                  underline: const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Plugins', style: TextStyle(color: AppTheme.gold, fontSize: 14, fontWeight: FontWeight.w600)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Enable Lua plugin support', style: TextStyle(color: AppTheme.gold)),
                Switch(
                  value: _pluginsEnabled,
                  activeThumbColor: AppTheme.gold,
                  onChanged: (v) {
                    setState(() => _pluginsEnabled = v);
                    widget.settingsManager.saveSettings(pluginsEnabled: v);
                  },
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Per-plugin process isolation', style: TextStyle(color: AppTheme.gold)),
                Switch(
                  value: _pluginProcessIsolation,
                  activeThumbColor: AppTheme.gold,
                  onChanged: _pluginsEnabled
                      ? (v) {
                          setState(() => _pluginProcessIsolation = v);
                          widget.settingsManager.saveSettings(pluginProcessIsolation: v);
                        }
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Future features (WIP)', style: TextStyle(color: AppTheme.gold, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Enable built-in terminal (Coming Soon)', style: TextStyle(color: AppTheme.gold)),
                Switch(
                  value: _builtInTerminalEnabled,
                  activeThumbColor: AppTheme.gold,
                  onChanged: (v) {
                    setState(() => _builtInTerminalEnabled = v);
                    widget.settingsManager.saveSettings(builtInTerminalEnabled: v);
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text('- File previews, more actions (Coming Soon)', style: TextStyle(color: AppTheme.gold)),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    // Update the main explorer state with the new settings
                    widget.explorerState.setState(() {
                      widget.explorerState.pluginsEnabled = _pluginsEnabled;
                      widget.explorerState.pluginProcessIsolation = _pluginProcessIsolation;
                      widget.explorerState.autoCompute = widget.settingsManager.settings['autoCompute'] as bool;
                      widget.explorerState.lowSpec = widget.settingsManager.settings['lowSpec'] as bool;
                      widget.explorerState.builtInTerminalEnabled = _builtInTerminalEnabled;
                      widget.explorerState.luaPluginSupportEnabled = _luaPluginSupportEnabled;
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text('Close', style: TextStyle(color: AppTheme.gold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Widget buildSettingsDialog(BuildContext context, ExplorerHomeState explorerState) {
  return SettingsDialog(
    settingsManager: explorerState.settingsManager,
    explorerState: explorerState,
    initialPluginsEnabled: explorerState.pluginsEnabled,
    initialPluginProcessIsolation: explorerState.pluginProcessIsolation,
    initialConcurrency: explorerState.settingsManager.settings['concurrency'] as int,
    initialBuiltInTerminalEnabled: explorerState.builtInTerminalEnabled,
    initialLuaPluginSupportEnabled: explorerState.luaPluginSupportEnabled,
  );
}
