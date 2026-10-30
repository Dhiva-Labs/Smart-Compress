import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Appearance', style: Theme.of(context).textTheme.titleSmall),
          RadioGroup<ThemeMode>(
            groupValue: settings.themeMode,
            onChanged: (mode) {
              if (mode != null) notifier.setThemeMode(mode);
            },
            child: const Column(
              children: [
                RadioListTile<ThemeMode>(
                    value: ThemeMode.system, title: Text('System')),
                RadioListTile<ThemeMode>(
                    value: ThemeMode.light, title: Text('Light')),
                RadioListTile<ThemeMode>(
                    value: ThemeMode.dark, title: Text('Dark')),
              ],
            ),
          ),
          const Divider(),
          Text('Defaults', style: Theme.of(context).textTheme.titleSmall),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Default quality'),
            subtitle: Slider(
              value: settings.defaultQuality.toDouble(),
              min: 1,
              max: 100,
              divisions: 99,
              label: '${settings.defaultQuality}',
              onChanged: (v) => notifier.setDefaultQuality(v.round()),
            ),
            trailing: Text('${settings.defaultQuality}'),
          ),
          if (Platform.isAndroid)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Output folder'),
              subtitle: Text(
                  'Saved to the app\'s SmartCompress folder — use the Share '
                  'button on any result to export it anywhere. (Android '
                  'restricts direct writes to other folders.)'),
            )
          else
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Output folder'),
              subtitle:
                  Text(settings.outputDirectory ?? 'Same as source file'),
              trailing: Wrap(
                children: [
                  if (settings.outputDirectory != null)
                    IconButton(
                      tooltip: 'Reset to source folder',
                      icon: const Icon(Icons.restart_alt),
                      onPressed: () => notifier.setOutputDirectory(null),
                    ),
                  IconButton(
                    tooltip: 'Choose folder',
                    icon: const Icon(Icons.folder_open),
                    onPressed: () async {
                      final dir = await FilePicker.getDirectoryPath();
                      if (dir != null) notifier.setOutputDirectory(dir);
                    },
                  ),
                ],
              ),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Keep original files'),
            subtitle: const Text(
                'When off, source files are deleted after a successful job'),
            value: settings.keepOriginals,
            onChanged: (v) async {
              if (!v) {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete originals?'),
                    content: const Text(
                        'Source files will be permanently deleted after each '
                        'successful compression. Are you sure?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete originals')),
                    ],
                  ),
                );
                if (confirm != true) return;
              }
              notifier.setKeepOriginals(v);
            },
          ),
          const Divider(),
          const AboutListTile(
            icon: Icon(Icons.info_outline),
            applicationName: 'CompressX',
            applicationVersion: '1.0.0',
            applicationLegalese: '© 2026 DhivaLabs',
            aboutBoxChildren: [
              Text('CompressX by DhivaLabs.\n'
                  'Offline-first file compressor and converter — '
                  'all processing happens on this device.'),
            ],
          ),
        ],
      ),
    );
  }
}
