import 'package:file_picker/file_picker.dart' show FileType;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ffmpeg.dart';
import '../../core/history.dart';
import '../../core/models.dart';
import '../../core/output.dart';
import '../../core/settings.dart';
import '../../engines/media_engine.dart';
import '../../widgets/ffmpeg_banner.dart';
import '../../widgets/file_drop_area.dart';
import '../../widgets/responsive_row.dart';
import '../../widgets/job_list.dart';

class AudioScreen extends ConsumerStatefulWidget {
  const AudioScreen({super.key});

  @override
  ConsumerState<AudioScreen> createState() => _AudioScreenState();
}

class _AudioScreenState extends ConsumerState<AudioScreen> {
  final List<FileJob> _jobs = [];
  bool _running = false;

  String _outputFormat = 'mp3';
  int _bitrate = 128;
  int? _targetMb;

  Future<void> _run() async {
    final settings = ref.read(settingsProvider);
    setState(() => _running = true);

    for (final job in _jobs) {
      if (job.status == FileJobStatus.done) continue;
      setState(() => job.status = FileJobStatus.running);

      final outputPath = resolveOutputPath(
        inputPath: job.inputPath,
        outputDirectory: await effectiveOutputDirectory(
          settings.outputDirectory,
        ),
        newExtension: _outputFormat,
      );
      final result = await compressAudio(
        job.inputPath,
        outputPath,
        AudioOptions(
          bitrateKbps: _bitrate,
          targetBytes: _targetMb == null ? null : _targetMb! * 1024 * 1024,
        ),
      );

      setState(() {
        if (result.success) {
          job
            ..status = FileJobStatus.done
            ..outputPath = outputPath
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
        ref
            .read(historyProvider.notifier)
            .add(
              HistoryEntry(
                fileName: job.fileName,
                kind: JobKind.audio,
                inputBytes: result.inputBytes,
                outputBytes: result.outputBytes,
                date: DateTime.now(),
                elapsedMs: result.elapsedMs,
              ),
            );
      }
    }
    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    final ffmpegAvailable = ref.watch(ffmpegAvailableProvider).value ?? false;
    final lossless = _outputFormat == 'flac' || _outputFormat == 'wav';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Compressor'),
        actions: [
          if (_jobs.isNotEmpty)
            IconButton(
              tooltip: 'Clear list',
              icon: const Icon(Icons.clear_all),
              onPressed: _running ? null : () => setState(() => _jobs.clear()),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!ffmpegAvailable) const FfmpegBanner(),
          FileDropArea(
            allowedExtensions: audioFormats,
            fileType: FileType.audio,
            onFiles: (paths) => setState(() {
              for (final path in paths) {
                if (_jobs.any((j) => j.inputPath == path)) continue;
                _jobs.add(FileJob(path));
              }
            }),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ResponsiveRow(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _outputFormat,
                    decoration: const InputDecoration(labelText: 'Format'),
                    items: [
                      for (final f in audioFormats)
                        DropdownMenuItem(
                          value: f,
                          child: Text(f.toUpperCase()),
                        ),
                    ],
                    onChanged: (v) =>
                        setState(() => _outputFormat = v ?? 'mp3'),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: _bitrate,
                    decoration: const InputDecoration(labelText: 'Bitrate'),
                    items: const [
                      DropdownMenuItem(value: 64, child: Text('64 kbps')),
                      DropdownMenuItem(value: 96, child: Text('96 kbps')),
                      DropdownMenuItem(value: 128, child: Text('128 kbps')),
                      DropdownMenuItem(value: 192, child: Text('192 kbps')),
                      DropdownMenuItem(value: 256, child: Text('256 kbps')),
                      DropdownMenuItem(value: 320, child: Text('320 kbps')),
                    ],
                    onChanged: lossless
                        ? null
                        : (v) => setState(() => _bitrate = v ?? 128),
                  ),
                  DropdownButtonFormField<int?>(
                    initialValue: _targetMb,
                    decoration: const InputDecoration(labelText: 'Target size'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('None')),
                      DropdownMenuItem(value: 5, child: Text('5 MB')),
                      DropdownMenuItem(value: 10, child: Text('10 MB')),
                      DropdownMenuItem(value: 25, child: Text('25 MB')),
                    ],
                    onChanged: lossless
                        ? null
                        : (v) => setState(() => _targetMb = v),
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
          onPressed: _jobs.isEmpty || _running || !ffmpegAvailable
              ? null
              : _run,
          icon: const Icon(Icons.compress),
          label: Text(
            _running
                ? 'Processing…'
                : 'Convert ${_jobs.length} file${_jobs.length == 1 ? '' : 's'}',
          ),
        ),
      ),
    );
  }
}
