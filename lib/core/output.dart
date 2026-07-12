import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Builds the output path for a processed file: honours the configured
/// output directory (or falls back to the source folder), appends [suffix],
/// optionally swaps the extension, and never overwrites an existing file.
String resolveOutputPath({
  required String inputPath,
  String? outputDirectory,
  String suffix = '_compressed',
  String? newExtension,
}) {
  final dir = outputDirectory ?? p.dirname(inputPath);
  final base = p.basenameWithoutExtension(inputPath);
  final ext = newExtension ?? p.extension(inputPath).replaceFirst('.', '');

  var candidate = p.join(dir, '$base$suffix.$ext');
  var counter = 1;
  while (File(candidate).existsSync()) {
    candidate = p.join(dir, '$base$suffix (${counter++}).$ext');
  }
  return candidate;
}

/// Where outputs should go.
///
/// Android's scoped storage means neither a folder picked via SAF (a path
/// `dart:io` cannot write to) nor the source folder (file_picker's hidden
/// cache) is reliable — so outputs always go to the app's own, real
/// `SmartCompress` folder there, and results are exported with the system
/// share sheet. Desktop honours [configured], falling back to the source
/// folder (null).
Future<String?> effectiveOutputDirectory(String? configured) async {
  if (!Platform.isAndroid) return configured;
  final base = await getExternalStorageDirectory() ??
      await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(base.path, 'SmartCompress'))
    ..createSync(recursive: true);
  return dir.path;
}
