import 'dart:io';

import '../core/ffmpeg.dart';

class MediaResult {
  final bool success;
  final String? error;
  final int inputBytes;
  final int outputBytes;
  final int elapsedMs;

  const MediaResult({
    required this.success,
    this.error,
    this.inputBytes = 0,
    this.outputBytes = 0,
    this.elapsedMs = 0,
  });
}

const videoFormats = ['mp4', 'mkv', 'mov', 'avi', 'webm'];
const audioFormats = ['mp3', 'aac', 'ogg', 'flac', 'wav', 'm4a'];

class VideoOptions {
  /// Output height in pixels (width scales to keep aspect); null keeps source.
  final int? height;

  /// Constant rate factor 0–51; lower is better quality. Ignored when
  /// [videoBitrateKbps] or [targetBytes] is set.
  final int crf;
  final int? videoBitrateKbps;
  final int? targetBytes;
  final bool removeAudio;
  final int? fps;

  const VideoOptions({
    this.height,
    this.crf = 26,
    this.videoBitrateKbps,
    this.targetBytes,
    this.removeAudio = false,
    this.fps,
  });
}

Future<MediaResult> compressVideo(
    String inputPath, String outputPath, VideoOptions options) async {
  final stopwatch = Stopwatch()..start();
  final inputBytes = File(inputPath).lengthSync();
  final ext = outputPath.split('.').last.toLowerCase();

  final args = <String>['-i', inputPath];

  if (options.height != null) {
    args.addAll(['-vf', 'scale=-2:${options.height}']);
  }
  if (options.fps != null) {
    args.addAll(['-r', '${options.fps}']);
  }

  // Codec by container.
  if (ext == 'webm') {
    args.addAll(['-c:v', 'libvpx-vp9']);
  } else {
    args.addAll(['-c:v', 'libx264', '-preset', 'medium']);
  }

  int? bitrate = options.videoBitrateKbps;
  if (options.targetBytes != null) {
    final duration = await ExternalTools.mediaDurationSeconds(inputPath);
    if (duration == null || duration <= 0) {
      return const MediaResult(
          success: false,
          error: 'Could not read media duration for target-size mode.');
    }
    const audioKbps = 128;
    final totalKbps = (options.targetBytes! * 8 / 1000 / duration).floor();
    bitrate = (totalKbps - (options.removeAudio ? 0 : audioKbps))
        .clamp(50, 100000);
  }

  if (bitrate != null) {
    args.addAll(['-b:v', '${bitrate}k', '-maxrate', '${bitrate}k',
        '-bufsize', '${bitrate * 2}k']);
  } else if (ext == 'webm') {
    args.addAll(['-crf', '${options.crf}', '-b:v', '0']);
  } else {
    args.addAll(['-crf', '${options.crf}']);
  }

  if (options.removeAudio) {
    args.add('-an');
  } else {
    args.addAll(['-c:a', 'aac', '-b:a', '128k']);
    if (ext == 'webm') {
      // WebM cannot carry AAC.
      args
        ..removeRange(args.length - 4, args.length)
        ..addAll(['-c:a', 'libopus', '-b:a', '128k']);
    }
  }

  args.add(outputPath);
  final (ok, log) = await ExternalTools.runFfmpeg(args);
  stopwatch.stop();
  if (!ok) return MediaResult(success: false, error: _tail(log));
  return MediaResult(
    success: true,
    inputBytes: inputBytes,
    outputBytes: File(outputPath).lengthSync(),
    elapsedMs: stopwatch.elapsedMilliseconds,
  );
}

class AudioOptions {
  final int bitrateKbps;
  final int? targetBytes;

  const AudioOptions({this.bitrateKbps = 128, this.targetBytes});
}

Future<MediaResult> compressAudio(
    String inputPath, String outputPath, AudioOptions options) async {
  final stopwatch = Stopwatch()..start();
  final inputBytes = File(inputPath).lengthSync();
  final ext = outputPath.split('.').last.toLowerCase();

  var bitrate = options.bitrateKbps;
  if (options.targetBytes != null) {
    final duration = await ExternalTools.mediaDurationSeconds(inputPath);
    if (duration == null || duration <= 0) {
      return const MediaResult(
          success: false,
          error: 'Could not read media duration for target-size mode.');
    }
    bitrate = (options.targetBytes! * 8 / 1000 / duration).floor().clamp(8, 512);
  }

  final codec = switch (ext) {
    'mp3' => 'libmp3lame',
    'aac' || 'm4a' => 'aac',
    'ogg' => 'libvorbis',
    'flac' => 'flac',
    'wav' => 'pcm_s16le',
    _ => null,
  };
  if (codec == null) {
    return MediaResult(
        success: false,
        error: 'Unsupported output format .$ext — supported: '
            '${audioFormats.join(', ')}');
  }

  final args = <String>['-i', inputPath, '-vn', '-c:a', codec];
  if (ext != 'flac' && ext != 'wav') {
    args.addAll(['-b:a', '${bitrate}k']);
  }
  args.add(outputPath);

  final (ok, log) = await ExternalTools.runFfmpeg(args);
  stopwatch.stop();
  if (!ok) return MediaResult(success: false, error: _tail(log));
  return MediaResult(
    success: true,
    inputBytes: inputBytes,
    outputBytes: File(outputPath).lengthSync(),
    elapsedMs: stopwatch.elapsedMilliseconds,
  );
}

String _tail(String log) {
  final lines = log.trim().split('\n');
  return lines.skip((lines.length - 6).clamp(0, lines.length)).join('\n');
}
