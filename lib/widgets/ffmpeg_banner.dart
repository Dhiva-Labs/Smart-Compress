import 'package:flutter/material.dart';

import '../core/ffmpeg.dart';

/// Shown when ffmpeg is missing — video/audio depend on it.
class FfmpegBanner extends StatelessWidget {
  const FfmpegBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                ExternalTools.isDesktop
                    ? 'FFmpeg was not found. Install it to enable video and '
                        'audio processing:\nLinux: sudo apt install ffmpeg — '
                        'Windows: winget install ffmpeg'
                    : 'Video and audio processing are currently desktop-only. '
                        'Android support is planned.',
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
