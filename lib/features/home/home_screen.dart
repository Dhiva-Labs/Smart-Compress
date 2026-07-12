import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings.dart';
import '../archive/archive_screen.dart';
import '../audio/audio_screen.dart';
import '../history/history_screen.dart';
import '../image/image_screen.dart';
import '../pdf/pdf_screen.dart';
import '../settings/settings_screen.dart';
import '../video/video_screen.dart';

class _Module {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget Function() screen;

  const _Module(this.title, this.subtitle, this.icon, this.screen);
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static final _modules = <_Module>[
    _Module('Image Compressor', 'Shrink JPG, PNG, WEBP and more',
        Icons.image_outlined, () => const ImageScreen()),
    _Module('Image Converter', 'Convert between image formats',
        Icons.swap_horiz, () => const ImageScreen(convertMode: true)),
    _Module('PDF Tools', 'Compress, merge, images → PDF',
        Icons.picture_as_pdf_outlined, () => const PdfScreen()),
    _Module('Video Compressor', 'Resize, re-encode, target size',
        Icons.videocam_outlined, () => const VideoScreen()),
    _Module('Audio Compressor', 'Convert and change bitrate',
        Icons.audiotrack_outlined, () => const AudioScreen()),
    _Module('Archive', 'ZIP, TAR, TAR.GZ — create & extract',
        Icons.folder_zip_outlined, () => const ArchiveScreen()),
    _Module('History', 'Past jobs and storage saved',
        Icons.history, () => const HistoryScreen()),
    _Module('Settings', 'Theme, quality, output folder',
        Icons.settings_outlined, () => const SettingsScreen()),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text.rich(
          TextSpan(children: [
            TextSpan(text: 'CompressX '),
            TextSpan(
                text: 'by DhivaLabs',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.normal)),
          ]),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: isDark ? 'Switch to light theme' : 'Switch to dark theme',
            icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            onPressed: () => ref
                .read(settingsProvider.notifier)
                .setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isPhone = constraints.maxWidth < 500;
          final columns =
              isPhone ? 2 : (constraints.maxWidth / 260).floor().clamp(2, 4);
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Card(
                    color: scheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(Icons.lock_outline,
                              color: scheme.onPrimaryContainer),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Everything runs on this device. '
                              'No uploads, no ads, no tracking.',
                              style:
                                  TextStyle(color: scheme.onPrimaryContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid.count(
                  crossAxisCount: columns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: isPhone ? 0.95 : 1.9,
                  children: [
                    for (final module in _modules)
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => module.screen()),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(module.icon,
                                    size: 28, color: scheme.primary),
                                const SizedBox(height: 8),
                                Text(module.title,
                                    maxLines: isPhone ? 2 : 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                const SizedBox(height: 2),
                                Flexible(
                                  child: Text(
                                    module.subtitle,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                            color: scheme.onSurfaceVariant),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
