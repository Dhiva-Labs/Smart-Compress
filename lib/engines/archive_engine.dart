import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

enum ArchiveFormat { zip, tar, tarGz }

extension ArchiveFormatExt on ArchiveFormat {
  String get extension => switch (this) {
        ArchiveFormat.zip => 'zip',
        ArchiveFormat.tar => 'tar',
        ArchiveFormat.tarGz => 'tar.gz',
      };

  String get label => switch (this) {
        ArchiveFormat.zip => 'ZIP',
        ArchiveFormat.tar => 'TAR',
        ArchiveFormat.tarGz => 'TAR.GZ',
      };
}

class ArchiveJobRequest {
  final List<String> inputPaths; // files and/or directories
  final String outputPath;
  final ArchiveFormat format;
  final String? password; // ZIP only (AES)
  final int level; // 0–9 deflate level

  const ArchiveJobRequest({
    required this.inputPaths,
    required this.outputPath,
    required this.format,
    this.password,
    this.level = 6,
  });
}

class ArchiveJobResult {
  final bool success;
  final String? error;
  final int inputBytes;
  final int outputBytes;
  final int fileCount;
  final int elapsedMs;

  const ArchiveJobResult({
    required this.success,
    this.error,
    this.inputBytes = 0,
    this.outputBytes = 0,
    this.fileCount = 0,
    this.elapsedMs = 0,
  });
}

/// Top-level so it can run in a background isolate via `compute`.
ArchiveJobResult createArchive(ArchiveJobRequest request) {
  final stopwatch = Stopwatch()..start();
  try {
    final archive = Archive();
    var inputBytes = 0;
    var fileCount = 0;

    void addFile(File file, String archivePath) {
      final data = file.readAsBytesSync();
      inputBytes += data.length;
      fileCount++;
      archive.add(ArchiveFile.bytes(archivePath, data));
    }

    for (final path in request.inputPaths) {
      final type = FileSystemEntity.typeSync(path);
      if (type == FileSystemEntityType.file) {
        addFile(File(path), p.basename(path));
      } else if (type == FileSystemEntityType.directory) {
        final root = Directory(path);
        final base = p.basename(path);
        for (final entity in root.listSync(recursive: true)) {
          if (entity is File) {
            addFile(entity, p.join(base, p.relative(entity.path, from: path)));
          }
        }
      }
    }

    final List<int> encoded;
    switch (request.format) {
      case ArchiveFormat.zip:
        encoded = ZipEncoder(password: request.password)
            .encodeBytes(archive, level: request.level.clamp(0, 9));
      case ArchiveFormat.tar:
        encoded = TarEncoder().encodeBytes(archive);
      case ArchiveFormat.tarGz:
        encoded = GZipEncoder()
            .encodeBytes(TarEncoder().encodeBytes(archive),
                level: request.level.clamp(1, 9));
    }

    File(request.outputPath).writeAsBytesSync(encoded);
    stopwatch.stop();
    return ArchiveJobResult(
      success: true,
      inputBytes: inputBytes,
      outputBytes: encoded.length,
      fileCount: fileCount,
      elapsedMs: stopwatch.elapsedMilliseconds,
    );
  } catch (e) {
    return ArchiveJobResult(success: false, error: '$e');
  }
}

class ExtractRequest {
  final String archivePath;
  final String outputDirectory;
  final String? password;

  const ExtractRequest({
    required this.archivePath,
    required this.outputDirectory,
    this.password,
  });
}

class ExtractResult {
  final bool success;
  final String? error;
  final int fileCount;

  const ExtractResult({required this.success, this.error, this.fileCount = 0});
}

/// Top-level so it can run in a background isolate via `compute`.
ExtractResult extractArchive(ExtractRequest request) {
  try {
    final lower = request.archivePath.toLowerCase();
    final bytes = File(request.archivePath).readAsBytesSync();
    final Archive archive;
    if (lower.endsWith('.zip')) {
      archive = ZipDecoder().decodeBytes(bytes, password: request.password);
    } else if (lower.endsWith('.tar.gz') || lower.endsWith('.tgz')) {
      archive = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
    } else if (lower.endsWith('.gz')) {
      final name = p.basenameWithoutExtension(request.archivePath);
      File(p.join(request.outputDirectory, name))
          .writeAsBytesSync(GZipDecoder().decodeBytes(bytes));
      return const ExtractResult(success: true, fileCount: 1);
    } else if (lower.endsWith('.tar')) {
      archive = TarDecoder().decodeBytes(bytes);
    } else {
      return const ExtractResult(
          success: false,
          error: 'Unsupported archive type. Supported: zip, tar, tar.gz, gz');
    }

    var count = 0;
    for (final file in archive) {
      if (!file.isFile) continue;
      // Guard against path traversal entries like ../../etc/passwd.
      final target =
          p.normalize(p.join(request.outputDirectory, file.name));
      if (!p.isWithin(request.outputDirectory, target)) continue;
      File(target)
        ..createSync(recursive: true)
        ..writeAsBytesSync(file.content);
      count++;
    }
    return ExtractResult(success: true, fileCount: count);
  } catch (e) {
    return ExtractResult(success: false, error: '$e');
  }
}
