import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../core/format.dart';
import '../../core/history.dart';
import '../../core/models.dart';
import '../../core/output.dart';
import '../../core/settings.dart';
import '../../engines/archive_engine.dart';
import '../../widgets/file_drop_area.dart';
import '../../widgets/responsive_row.dart';

class ArchiveScreen extends ConsumerStatefulWidget {
  const ArchiveScreen({super.key});

  @override
  ConsumerState<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends ConsumerState<ArchiveScreen> {
  // Create
  final List<String> _inputs = [];
  ArchiveFormat _format = ArchiveFormat.zip;
  double _level = 6;
  final _passwordController = TextEditingController();
  bool _working = false;

  // Extract
  String? _archivePath;
  final _extractPasswordController = TextEditingController();

  String? _message;
  bool _messageIsError = false;
  String? _lastOutputPath;

  @override
  void dispose() {
    _passwordController.dispose();
    _extractPasswordController.dispose();
    super.dispose();
  }

  Future<void> _addFolder() async {
    final dir = await FilePicker.getDirectoryPath();
    if (dir != null && !_inputs.contains(dir)) {
      setState(() => _inputs.add(dir));
    }
  }

  Future<void> _create() async {
    final settings = ref.read(settingsProvider);
    final password = _passwordController.text.trim();
    final output = resolveOutputPath(
      inputPath: _inputs.first,
      outputDirectory: await effectiveOutputDirectory(settings.outputDirectory),
      suffix: '',
      newExtension: _format.extension,
    );
    setState(() {
      _working = true;
      _message = null;
    });
    final result = await compute(
      createArchive,
      ArchiveJobRequest(
        inputPaths: List.of(_inputs),
        outputPath: output,
        format: _format,
        password: _format == ArchiveFormat.zip && password.isNotEmpty
            ? password
            : null,
        level: _level.round(),
      ),
    );
    setState(() {
      _working = false;
      if (result.success) {
        _message =
            'Created ${p.basename(output)} — ${result.fileCount} files, '
            '${formatBytes(result.inputBytes)} → ${formatBytes(result.outputBytes)} '
            '(${savedPercent(result.inputBytes, result.outputBytes).toStringAsFixed(1)}% saved)';
        _messageIsError = false;
        _lastOutputPath = output;
      } else {
        _message = result.error;
        _messageIsError = true;
        _lastOutputPath = null;
      }
    });
    if (result.success) {
      ref
          .read(historyProvider.notifier)
          .add(
            HistoryEntry(
              fileName: p.basename(output),
              kind: JobKind.archive,
              inputBytes: result.inputBytes,
              outputBytes: result.outputBytes,
              date: DateTime.now(),
              elapsedMs: result.elapsedMs,
            ),
          );
    }
  }

  Future<void> _extract() async {
    // Android's picked directories aren't dart:io-writable (scoped
    // storage), so extraction goes into the app's SmartCompress folder.
    final String destination;
    if (Platform.isAndroid) {
      final base = (await effectiveOutputDirectory(null))!;
      destination = p.join(
        base,
        p.basename(_archivePath!).replaceAll(RegExp(r'\..*$'), ''),
      );
      Directory(destination).createSync(recursive: true);
    } else {
      final picked = await FilePicker.getDirectoryPath(
        dialogTitle: 'Extract to folder',
      );
      if (picked == null) return;
      destination = picked;
    }
    setState(() {
      _working = true;
      _message = null;
    });
    final password = _extractPasswordController.text.trim();
    final result = await compute(
      extractArchive,
      ExtractRequest(
        archivePath: _archivePath!,
        outputDirectory: destination,
        password: password.isEmpty ? null : password,
      ),
    );
    setState(() {
      _working = false;
      _message = result.success
          ? 'Extracted ${result.fileCount} files to $destination'
          : result.error;
      _messageIsError = !result.success;
      _lastOutputPath = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Archive'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Create'),
              Tab(text: 'Extract'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FileDropArea(
                  label: 'Add files to archive',
                  onFiles: (paths) => setState(
                    () => _inputs.addAll(
                      paths.where((path) => !_inputs.contains(path)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Scoped storage blocks reading arbitrary folders on
                // Android, so folder input is desktop-only.
                if (!Platform.isAndroid)
                  OutlinedButton.icon(
                    onPressed: _addFolder,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Add a folder'),
                  ),
                for (var i = 0; i < _inputs.length; i++)
                  ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.insert_drive_file_outlined,
                      size: 18,
                    ),
                    title: Text(
                      _inputs[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _inputs.removeAt(i)),
                    ),
                  ),
                const SizedBox(height: 8),
                ResponsiveRow(
                  children: [
                    DropdownButtonFormField<ArchiveFormat>(
                      initialValue: _format,
                      decoration: const InputDecoration(labelText: 'Format'),
                      items: [
                        for (final f in ArchiveFormat.values)
                          DropdownMenuItem(value: f, child: Text(f.label)),
                      ],
                      onChanged: (v) =>
                          setState(() => _format = v ?? ArchiveFormat.zip),
                    ),
                    if (_format != ArchiveFormat.tar)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Level: ${_level.round()}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Slider(
                            value: _level,
                            min: 1,
                            max: 9,
                            divisions: 8,
                            onChanged: (v) => setState(() => _level = v),
                          ),
                        ],
                      ),
                  ],
                ),
                if (_format == ArchiveFormat.zip)
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password (optional, AES-256)',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _inputs.isEmpty || _working ? null : _create,
                  icon: const Icon(Icons.archive),
                  label: Text(_working ? 'Working…' : 'Create archive'),
                ),
                if (_message != null) _messageCard(scheme),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FileDropArea(
                  allowedExtensions: const ['zip', 'tar', 'gz', 'tgz'],
                  allowMultiple: false,
                  label: 'Pick an archive to extract',
                  onFiles: (paths) =>
                      setState(() => _archivePath = paths.first),
                ),
                if (_archivePath != null)
                  ListTile(
                    leading: const Icon(Icons.folder_zip),
                    title: Text(p.basename(_archivePath!)),
                  ),
                TextField(
                  controller: _extractPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password (if encrypted)',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _archivePath == null || _working ? null : _extract,
                  icon: const Icon(Icons.unarchive),
                  label: Text(_working ? 'Working…' : 'Extract…'),
                ),
                if (_message != null) _messageCard(scheme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageCard(ColorScheme scheme) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Card(
      color: _messageIsError
          ? scheme.errorContainer
          : scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _message!,
                style: TextStyle(
                  color: _messageIsError
                      ? scheme.onErrorContainer
                      : scheme.onSecondaryContainer,
                ),
              ),
            ),
            if (_lastOutputPath != null && Platform.isAndroid)
              IconButton(
                tooltip: 'Share',
                icon: Icon(
                  Icons.share,
                  color: scheme.onSecondaryContainer,
                  size: 20,
                ),
                onPressed: () => SharePlus.instance.share(
                  ShareParams(files: [XFile(_lastOutputPath!)]),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
