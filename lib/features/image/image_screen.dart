import 'dart:io';

import 'package:file_picker/file_picker.dart' show FileType;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/history.dart';
import '../../core/models.dart';
import '../../core/output.dart';
import '../../core/settings.dart';
import '../../engines/image_engine.dart';
import '../../widgets/file_drop_area.dart';
import '../../widgets/job_list.dart';
import '../../widgets/responsive_row.dart';

class _Preset {
  final String label;
  final int quality;
  final int? maxDimension;
  final int? targetBytes;

  const _Preset(this.label,
      {required this.quality, this.maxDimension, this.targetBytes});
}

const _presets = [
  _Preset('Email (< 1 MB)', quality: 80, targetBytes: 1024 * 1024),
  _Preset('WhatsApp', quality: 75, maxDimension: 1600),
  _Preset('Instagram', quality: 85, maxDimension: 1080),
  _Preset('Website', quality: 72, maxDimension: 1920),
  _Preset('Max compression', quality: 40, maxDimension: 1280),
  _Preset('Best quality', quality: 95),
];

const _targetSizeChoices = <String, int?>{
  'None': null,
  '100 KB': 100 * 1024,
  '250 KB': 250 * 1024,
  '500 KB': 500 * 1024,
  '1 MB': 1024 * 1024,
};

class ImageScreen extends ConsumerStatefulWidget {
  /// When true the screen leads with format conversion instead of size.
  final bool convertMode;

  const ImageScreen({super.key, this.convertMode = false});

  @override
  ConsumerState<ImageScreen> createState() => _ImageScreenState();
}

class _ImageScreenState extends ConsumerState<ImageScreen> {
  final List<FileJob> _jobs = [];
  bool _running = false;

  late int _quality = ref.read(settingsProvider).defaultQuality;
  String _outputFormat = 'keep'; // 'keep' or an encodable extension
  int? _maxDimension;
  int? _targetBytes;
  bool _stripMetadata = false;
  int? _activePreset;

  @override
  void initState() {
    super.initState();
    if (widget.convertMode) _outputFormat = 'jpg';
  }

  void _addFiles(List<String> paths) {
    setState(() {
      for (final path in paths) {
        if (_jobs.any((j) => j.inputPath == path)) continue;
        _jobs.add(FileJob(path));
      }
    });
  }

  void _applyPreset(int index) {
    final preset = _presets[index];
    setState(() {
      _activePreset = index;
      _quality = preset.quality;
      _maxDimension = preset.maxDimension;
      _targetBytes = preset.targetBytes;
      if (preset.targetBytes != null) _outputFormat = 'jpg';
    });
  }

  Future<void> _run() async {
    final settings = ref.read(settingsProvider);
    setState(() {
      _running = true;
      for (final job in _jobs) {
        if (job.status != FileJobStatus.done) {
          job.status = FileJobStatus.pending;
        }
      }
    });

    for (final job in _jobs) {
      if (job.status == FileJobStatus.done) continue;
      setState(() => job.status = FileJobStatus.running);

      // Already at or under the requested target? Nothing to do — forcing a
      // JPEG re-encode could only grow the file.
      final inputLength = File(job.inputPath).lengthSync();
      if (_targetBytes != null && inputLength <= _targetBytes!) {
        setState(() {
          job
            ..status = FileJobStatus.done
            ..outputPath = job.inputPath
            ..inputBytes = inputLength
            ..outputBytes = inputLength
            ..elapsedMs = 0;
        });
        ref.read(historyProvider.notifier).add(HistoryEntry(
              fileName: job.fileName,
              kind: JobKind.image,
              inputBytes: inputLength,
              outputBytes: inputLength,
              date: DateTime.now(),
              elapsedMs: 0,
            ));
        continue;
      }

      final inputExt = job.inputPath.split('.').last.toLowerCase();
      var outExt = _outputFormat == 'keep' ? inputExt : _outputFormat;
      if (outExt == 'jpeg') outExt = 'jpg';
      // Target size only works for JPEG output.
      if (_targetBytes != null) outExt = 'jpg';
      if (!encodableFormats.contains(outExt)) outExt = 'jpg';

      final outputPath = resolveOutputPath(
        inputPath: job.inputPath,
        outputDirectory:
            await effectiveOutputDirectory(settings.outputDirectory),
        suffix: widget.convertMode ? '_converted' : '_compressed',
        newExtension: outExt,
      );

      final result = await compute(
        processImage,
        ImageJobRequest(
          inputPath: job.inputPath,
          outputPath: outputPath,
          quality: _quality,
          maxWidth: _maxDimension,
          maxHeight: _maxDimension,
          targetBytes: _targetBytes,
          stripMetadata: _stripMetadata,
          preferSmaller: !widget.convertMode,
        ),
      );

      setState(() {
        if (result.success) {
          job
            ..status = FileJobStatus.done
            ..outputPath = result.outputPath
            ..inputBytes = result.inputBytes
            ..outputBytes = result.outputBytes
            ..elapsedMs = result.elapsedMs;
        } else {
          job
            ..status = FileJobStatus.failed
            ..error = result.error;
        }
      });

      if (result.success) {
        ref.read(historyProvider.notifier).add(HistoryEntry(
              fileName: job.fileName,
              kind: JobKind.image,
              inputBytes: result.inputBytes,
              outputBytes: result.outputBytes,
              date: DateTime.now(),
              elapsedMs: result.elapsedMs,
            ));
        if (!settings.keepOriginals && result.outputPath != job.inputPath) {
          try {
            File(job.inputPath).deleteSync();
          } catch (_) {}
        }
      }
    }

    if (mounted) setState(() => _running = false);
  }

  void _showComparison(FileJob job) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 600),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(job.fileName,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Flexible(
                  child: MediaQuery.sizeOf(context).width < 600
                      ? Column(
                          children: [
                            Expanded(
                                child: _previewPane(
                                    'Original',
                                    formatBytes(job.inputBytes),
                                    job.inputPath)),
                            const SizedBox(height: 12),
                            Expanded(
                                child: _previewPane(
                                    'Compressed',
                                    formatBytes(job.outputBytes),
                                    job.outputPath!)),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                                child: _previewPane(
                                    'Original',
                                    formatBytes(job.inputBytes),
                                    job.inputPath)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _previewPane(
                                    'Compressed',
                                    formatBytes(job.outputBytes),
                                    job.outputPath!)),
                          ],
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                    '${savedPercent(job.inputBytes, job.outputBytes).toStringAsFixed(1)}% smaller — pinch or scroll to zoom'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _previewPane(String label, String size, String path) {
    return Column(
      children: [
        Text('$label · $size'),
        const SizedBox(height: 6),
        Expanded(
          child: InteractiveViewer(
            maxScale: 8,
            child: Image.file(File(path), fit: BoxFit.contain),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPending =
        _jobs.any((j) => j.status != FileJobStatus.done) && _jobs.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.convertMode ? 'Image Converter' : 'Image Compressor'),
        actions: [
          if (_jobs.isNotEmpty)
            IconButton(
              tooltip: 'Clear list',
              icon: const Icon(Icons.clear_all),
              onPressed:
                  _running ? null : () => setState(() => _jobs.clear()),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FileDropArea(
            allowedExtensions: decodableExtensions,
            fileType: FileType.image,
            onFiles: _addFiles,
          ),
          const SizedBox(height: 16),
          if (!widget.convertMode) ...[
            Text('Presets', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _presets.length; i++)
                  ChoiceChip(
                    label: Text(_presets[i].label),
                    selected: _activePreset == i,
                    onSelected: (_) => _applyPreset(i),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Options',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const SizedBox(width: 90, child: Text('Quality')),
                      Expanded(
                        child: Slider(
                          value: _quality.toDouble(),
                          min: 1,
                          max: 100,
                          divisions: 99,
                          label: '$_quality',
                          onChanged: _targetBytes != null
                              ? null
                              : (v) => setState(() {
                                    _quality = v.round();
                                    _activePreset = null;
                                  }),
                        ),
                      ),
                      SizedBox(width: 36, child: Text('$_quality')),
                    ],
                  ),
                  ResponsiveRow(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _outputFormat,
                        decoration:
                            const InputDecoration(labelText: 'Format'),
                        items: [
                          const DropdownMenuItem(
                              value: 'keep', child: Text('Keep original')),
                          for (final f in encodableFormats)
                            DropdownMenuItem(
                                value: f, child: Text(f.toUpperCase())),
                        ],
                        onChanged: (v) =>
                            setState(() => _outputFormat = v ?? 'keep'),
                      ),
                      DropdownButtonFormField<int?>(
                        initialValue: _maxDimension,
                        decoration: const InputDecoration(
                            labelText: 'Max dimension'),
                        items: const [
                          DropdownMenuItem(
                              value: null, child: Text('Original')),
                          DropdownMenuItem(
                              value: 3840, child: Text('3840 px')),
                          DropdownMenuItem(
                              value: 1920, child: Text('1920 px')),
                          DropdownMenuItem(
                              value: 1280, child: Text('1280 px')),
                          DropdownMenuItem(
                              value: 800, child: Text('800 px')),
                        ],
                        onChanged: (v) => setState(() {
                          _maxDimension = v;
                          _activePreset = null;
                        }),
                      ),
                      DropdownButtonFormField<int?>(
                        initialValue: _targetBytes,
                        decoration: const InputDecoration(
                            labelText: 'Target size (JPG)'),
                        items: [
                          for (final entry in _targetSizeChoices.entries)
                            DropdownMenuItem(
                                value: entry.value,
                                child: Text(entry.key)),
                        ],
                        onChanged: (v) => setState(() {
                          _targetBytes = v;
                          _activePreset = null;
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Remove metadata (EXIF)'),
                    value: _stripMetadata,
                    onChanged: (v) => setState(() => _stripMetadata = v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_jobs.isNotEmpty) ...[
            BatchSummary(jobs: _jobs),
            const SizedBox(height: 8),
            JobList(
              jobs: _jobs,
              onTapDone: _showComparison,
              onRemove: _running
                  ? null
                  : (job) => setState(() => _jobs.remove(job)),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          onPressed: hasPending && !_running ? _run : null,
          icon: _running
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.compress),
          label: Text(_running
              ? 'Processing…'
              : widget.convertMode
                  ? 'Convert ${_jobs.length} file${_jobs.length == 1 ? '' : 's'}'
                  : 'Compress ${_jobs.length} file${_jobs.length == 1 ? '' : 's'}'),
        ),
      ),
    );
  }
}
