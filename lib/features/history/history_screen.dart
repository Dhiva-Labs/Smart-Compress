import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/history.dart';
import '../../core/models.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  IconData _iconFor(JobKind kind) => switch (kind) {
        JobKind.image => Icons.image_outlined,
        JobKind.pdf => Icons.picture_as_pdf_outlined,
        JobKind.video => Icons.videocam_outlined,
        JobKind.audio => Icons.audiotrack_outlined,
        JobKind.archive => Icons.folder_zip_outlined,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(historyProvider);
    final stats = ref.watch(historyStatsProvider);
    final scheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat.yMMMd().add_Hm();

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          if (entries.isNotEmpty)
            IconButton(
              tooltip: 'Clear history',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear history?'),
                    content: const Text(
                        'This removes the log only — no files are deleted.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Clear')),
                    ],
                  ),
                );
                if (confirm == true) {
                  ref.read(historyProvider.notifier).clear();
                }
              },
            ),
        ],
      ),
      body: entries.isEmpty
          ? const Center(child: Text('No files processed yet.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    _statCard(context, 'Files processed', '${stats.totalFiles}'),
                    const SizedBox(width: 12),
                    _statCard(
                        context, 'Storage saved', formatBytes(stats.totalSaved)),
                    const SizedBox(width: 12),
                    _statCard(context, 'Most used',
                        stats.mostUsedKind?.name ?? '—'),
                  ],
                ),
                const SizedBox(height: 16),
                for (final entry in entries)
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    child: ListTile(
                      dense: true,
                      leading: Icon(_iconFor(entry.kind),
                          color: scheme.primary),
                      title: Text(entry.fileName,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                          '${formatBytes(entry.inputBytes)} → '
                          '${formatBytes(entry.outputBytes)} '
                          '(${savedPercent(entry.inputBytes, entry.outputBytes).toStringAsFixed(1)}% saved) · '
                          '${formatDuration(Duration(milliseconds: entry.elapsedMs))}'),
                      trailing: Text(dateFormat.format(entry.date),
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _statCard(BuildContext context, String label, String value) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Text(value, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(label,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
