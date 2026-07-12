import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Locates and runs external command-line tools (ffmpeg, ghostscript, qpdf)
/// on desktop platforms. Android has no system binaries, so everything here
/// reports unavailable there.
class ExternalTools {
  static bool get isDesktop =>
      Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  static Future<bool> has(String executable) async {
    if (!isDesktop) return false;
    try {
      final result = await Process.run(
        Platform.isWindows ? 'where' : 'which',
        [executable],
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Media duration in seconds, parsed from `ffmpeg -i` output.
  static Future<double?> mediaDurationSeconds(String path) async {
    try {
      final result = await Process.run('ffmpeg', ['-i', path]);
      final match = RegExp(r'Duration: (\d+):(\d+):(\d+(?:\.\d+)?)')
          .firstMatch(result.stderr as String);
      if (match == null) return null;
      return int.parse(match.group(1)!) * 3600 +
          int.parse(match.group(2)!) * 60 +
          double.parse(match.group(3)!);
    } catch (_) {
      return null;
    }
  }

  static Future<(bool success, String log)> runFfmpeg(
      List<String> args) async {
    try {
      final result =
          await Process.run('ffmpeg', ['-y', '-hide_banner', ...args]);
      return (result.exitCode == 0, result.stderr as String);
    } catch (e) {
      return (false, '$e');
    }
  }

  static Future<(bool success, String log)> run(
      String executable, List<String> args) async {
    try {
      final result = await Process.run(executable, args);
      final log = '${result.stdout}\n${result.stderr}';
      return (result.exitCode == 0, log);
    } catch (e) {
      return (false, '$e');
    }
  }
}

final ffmpegAvailableProvider =
    FutureProvider<bool>((ref) => ExternalTools.has('ffmpeg'));

final ghostscriptAvailableProvider =
    FutureProvider<bool>((ref) => ExternalTools.has('gs'));

final qpdfAvailableProvider =
    FutureProvider<bool>((ref) => ExternalTools.has('qpdf'));
