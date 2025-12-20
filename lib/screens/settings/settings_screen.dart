import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showHiddenFiles = false;
  String _defaultDirectory = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showHiddenFiles = prefs.getBool('showHiddenFiles') ?? false;
      _defaultDirectory = prefs.getString('defaultDirectory') ?? '';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showHiddenFiles', _showHiddenFiles);
    await prefs.setString('defaultDirectory', _defaultDirectory);

    // Show a snackbar to confirm settings were saved
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: 'Save Settings',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'File Explorer',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Show Hidden Files'),
                      subtitle: const Text('Display hidden files and directories'),
                      value: _showHiddenFiles,
                      onChanged: (value) {
                        setState(() {
                          _showHiddenFiles = value;
                        });
                      },
                      secondary: const Icon(Icons.visibility),
                    ),
                    ListTile(
                      title: const Text('Default Directory'),
                      subtitle: Text(_defaultDirectory.isEmpty
                          ? 'Not set (uses home directory)'
                          : _defaultDirectory),
                      trailing: const Icon(Icons.folder),
                      onTap: () async {
                        // In a real implementation, you would use a file picker here
                        // For now, we'll just show a dialog
                        final result = await showDialog<String>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Set Default Directory'),
                            content: TextField(
                              decoration: const InputDecoration(
                                hintText: 'Enter directory path',
                              ),
                              controller: TextEditingController(text: _defaultDirectory),
                              onSubmitted: (value) {
                                Navigator.pop(context, value);
                              },
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context, _defaultDirectory);
                                },
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );

                        if (result != null) {
                          setState(() {
                            _defaultDirectory = result;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              'About',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('App Version'),
                      subtitle: const Text('1.0.0'),
                      leading: const Icon(Icons.info),
                    ),
                    ListTile(
                      title: const Text('Developer'),
                      subtitle: const Text('Veridian Zenith'),
                      leading: const Icon(Icons.developer_mode),
                    ),
                    ListTile(
                      title: const Text('License'),
                      subtitle: const Text('MIT License'),
                      leading: const Icon(Icons.description),
                      onTap: () {
                        // Show license information
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('License Information'),
                            content: const SingleChildScrollView(
                              child: Text(
                                'Meshiji File Explorer\n'
                                'Linux Application\n\n'
                                'Copyright (c) 2025 Veridian Zenith\n\n'
                                'Permission is hereby granted, free of charge, to any person obtaining a copy\n'
                                'of this software and associated documentation files (the "Software"), to deal\n'
                                'in the Software without restriction, including without limitation the rights\n'
                                'to use, copy, modify, merge, publish, distribute, sublicense, and/or sell\n'
                                'copies of the Software, and to permit persons to whom the Software is\n'
                                'furnished to do so, subject to the following conditions:\n\n'
                                'The above copyright notice and this permission notice shall be included in all\n'
                                'copies or substantial portions of the Software.\n\n'
                                'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR\n'
                                'IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,\n'
                                'FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE\n'
                                'AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER\n'
                                'LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,\n'
                                'OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE\n'
                                'SOFTWARE.',
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save All Settings'),
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
