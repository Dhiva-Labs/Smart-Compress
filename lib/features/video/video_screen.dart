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

class VideoScreen extends ConsumerStatefulWidget {
  const VideoScreen({super.key});

  @override
  ConsumerState<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends ConsumerState<VideoScreen> {
  final List<FileJob> _jobs = [];
  bool _running = false;

  String _outputFormat = 'mp4';
  int? _height;
  int _crf = 26;
  int? _targetMb;
  bool _removeAudio = false;
  int? _fps;

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
      final result = await compressVideo(
        job.inputPath,
        outputPath,
        VideoOptions(
          height: _height,
          crf: _crf,
          targetBytes: _targetMb == null ? null : _targetMb! * 1024 * 1024,
          removeAudio: _removeAudio,
          fps: _fps,
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
                kind: JobKind.video,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Compressor'),
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
            allowedExtensions: videoFormats,
            fileType: FileType.video,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ResponsiveRow(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _outputFormat,
                        decoration: const InputDecoration(labelText: 'Format'),
                        items: [
                          for (final f in videoFormats)
                            DropdownMenuItem(
                              value: f,
                              child: Text(f.toUpperCase()),
                            ),
                        ],
                        onChanged: (v) =>
                            setState(() => _outputFormat = v ?? 'mp4'),
                      ),
                      DropdownButtonFormField<int?>(
                        initialValue: _height,
                        decoration: const InputDecoration(
                          labelText: 'Resolution',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: null,
                            child: Text('Original'),
                          ),
                          DropdownMenuItem(value: 1080, child: Text('1080p')),
                          DropdownMenuItem(value: 720, child: Text('720p')),
                          DropdownMenuItem(value: 480, child: Text('480p')),
                          DropdownMenuItem(value: 360, child: Text('360p')),
                        ],
                        onChanged: (v) => setState(() => _height = v),
                      ),
                      DropdownButtonFormField<int?>(
                        initialValue: _fps,
                        decoration: const InputDecoration(
                          labelText: 'Frame rate',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: null,
                            child: Text('Original'),
                          ),
                          DropdownMenuItem(value: 60, child: Text('60 fps')),
                          DropdownMenuItem(value: 30, child: Text('30 fps')),
                          DropdownMenuItem(value: 24, child: Text('24 fps')),
                        ],
                        onChanged: (v) => setState(() => _fps = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const SizedBox(width: 90, child: Text('Quality')),
                      Expanded(
                        child: Slider(
                          // Lower CRF = better quality; show it inverted.
                          value: (51 - _crf).toDouble(),
                          min: 11,
                          max: 33,
                          divisions: 22,
                          label: 'CRF $_crf',
                          onChanged: _targetMb != null
                              ? null
                              : (v) => setState(() => _crf = 51 - v.round()),
                        ),
                      ),
                      SizedBox(width: 60, child: Text('CRF $_crf')),
                    ],
                  ),
                  ResponsiveRow(
                    children: [
                      DropdownButtonFormField<int?>(
                        initialValue: _targetMb,
                        decoration: const InputDecoration(
                          labelText: 'Target size',
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('None')),
                          DropdownMenuItem(value: 10, child: Text('10 MB')),
                          DropdownMenuItem(
                            value: 25,
                            child: Text('25 MB (email)'),
                          ),
                          DropdownMenuItem(value: 50, child: Text('50 MB')),
                          DropdownMenuItem(value: 100, child: Text('100 MB')),
                        ],
                        onChanged: (v) => setState(() => _targetMb = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text('Remove audio'),
                        value: _removeAudio,
                        onChanged: (v) => setState(() => _removeAudio = v),
                      ),
                    ],
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
                : 'Compress ${_jobs.length} video${_jobs.length == 1 ? '' : 's'}',
          ),
        ),
      ),
    );
  }
}
