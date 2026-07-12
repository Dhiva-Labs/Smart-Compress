import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/format.dart';
import '../core/models.dart';

/// Batch progress list: one row per file with status, sizes and savings.
class JobList extends StatelessWidget {
  final List<FileJob> jobs;
  final void Function(FileJob job)? onTapDone;

  /// When set, each row gets a remove button (pass null while running).
  final void Function(FileJob job)? onRemove;

  const JobList({super.key, required this.jobs, this.onTapDone, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final job in jobs)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 3),
            child: ListTile(
              dense: true,
              leading: switch (job.status) {
                FileJobStatus.pending => Icon(
                  Icons.schedule,
                  color: scheme.outline,
                ),
                FileJobStatus.running => const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                FileJobStatus.done => Icon(
                  Icons.check_circle,
                  color: Colors.green.shade600,
                ),
                FileJobStatus.failed => Icon(Icons.error, color: scheme.error),
              },
              title: Text(
                job.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: switch (job.status) {
                FileJobStatus.done when job.outputBytes >= job.inputBytes =>
                  Text(
                    '${formatBytes(job.inputBytes)} — already optimized, '
                    'original kept',
                  ),
                FileJobStatus.done => Text(
                  '${formatBytes(job.inputBytes)} → '
                  '${formatBytes(job.outputBytes)}   '
                  '(${savedPercent(job.inputBytes, job.outputBytes).toStringAsFixed(1)}% saved, '
                  '${formatDuration(Duration(milliseconds: job.elapsedMs))})',
                ),
                FileJobStatus.failed => Text(
                  job.error ?? 'Failed',
                  maxLines: 2,
                ),
                _ => null,
              },
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (job.status == FileJobStatus.done &&
                      job.outputPath != null &&
                      Platform.isAndroid)
                    IconButton(
                      tooltip: 'Share',
                      icon: const Icon(Icons.share, size: 18),
                      onPressed: () => SharePlus.instance.share(
                        ShareParams(files: [XFile(job.outputPath!)]),
                      ),
                    ),
                  if (job.status == FileJobStatus.done &&
                      job.outputPath != null &&
                      !Platform.isAndroid)
                    IconButton(
                      tooltip: 'Copy output path',
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: job.outputPath!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Path copied')),
                        );
                      },
                    ),
                  if (onRemove != null && job.status != FileJobStatus.running)
                    IconButton(
                      tooltip: 'Remove from list',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => onRemove!(job),
                    ),
                ],
              ),
              onTap: job.status == FileJobStatus.done && onTapDone != null
                  ? () => onTapDone!(job)
                  : null,
            ),
          ),
      ],
    );
  }
}

/// Summary banner after a batch finishes.
class BatchSummary extends StatelessWidget {
  final List<FileJob> jobs;

  const BatchSummary({super.key, required this.jobs});

  @override
  Widget build(BuildContext context) {
    final done = jobs.where((j) => j.status == FileJobStatus.done).toList();
    final failed = jobs.where((j) => j.status == FileJobStatus.failed).length;
    if (done.isEmpty && failed == 0) return const SizedBox.shrink();
    final inBytes = done.fold<int>(0, (s, j) => s + j.inputBytes);
    final outBytes = done.fold<int>(0, (s, j) => s + j.outputBytes);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.insights, color: scheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${done.length} file${done.length == 1 ? '' : 's'} processed'
                '${failed > 0 ? ', $failed failed' : ''} — '
                '${formatBytes(inBytes)} → ${formatBytes(outBytes)} '
                '(${savedPercent(inBytes, outBytes).toStringAsFixed(1)}% saved)',
                style: TextStyle(color: scheme.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
