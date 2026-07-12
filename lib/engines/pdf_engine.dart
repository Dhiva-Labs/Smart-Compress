import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/ffmpeg.dart';

class PdfResult {
  final bool success;
  final String? error;
  final int inputBytes;
  final int outputBytes;
  final int elapsedMs;

  const PdfResult({
    required this.success,
    this.error,
    this.inputBytes = 0,
    this.outputBytes = 0,
    this.elapsedMs = 0,
  });
}

class ImagesToPdfRequest {
  final List<String> imagePaths;
  final String outputPath;

  /// Re-encode images as JPEG at this quality before embedding.
  final int quality;

  const ImagesToPdfRequest({
    required this.imagePaths,
    required this.outputPath,
    this.quality = 85,
  });
}

/// Builds a PDF with one page per image. Top-level so it can run via
/// `compute`.
Future<PdfResult> imagesToPdf(ImagesToPdfRequest request) async {
  final stopwatch = Stopwatch()..start();
  try {
    final doc = pw.Document();
    var inputBytes = 0;
    for (final path in request.imagePaths) {
      final raw = File(path).readAsBytesSync();
      inputBytes += raw.length;
      final decoded = img.decodeImage(raw);
      if (decoded == null) {
        return PdfResult(success: false, error: 'Cannot decode image: $path');
      }
      final jpeg = img.encodeJpg(decoded, quality: request.quality);
      final image = pw.MemoryImage(jpeg);
      final pageFormat = PdfPageFormat(
          decoded.width.toDouble(), decoded.height.toDouble());
      doc.addPage(pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(image, fit: pw.BoxFit.contain),
      ));
    }
    final bytes = await doc.save();
    File(request.outputPath).writeAsBytesSync(bytes);
    stopwatch.stop();
    return PdfResult(
      success: true,
      inputBytes: inputBytes,
      outputBytes: bytes.length,
      elapsedMs: stopwatch.elapsedMilliseconds,
    );
  } catch (e) {
    return PdfResult(success: false, error: '$e');
  }
}

enum PdfPreset { low, medium, high, maximum }

extension PdfPresetExt on PdfPreset {
  /// Ghostscript -dPDFSETTINGS value. "screen" is the most aggressive.
  String get gsSetting => switch (this) {
        PdfPreset.low => '/prepress',
        PdfPreset.medium => '/printer',
        PdfPreset.high => '/ebook',
        PdfPreset.maximum => '/screen',
      };

  String get label => switch (this) {
        PdfPreset.low => 'Low (best quality)',
        PdfPreset.medium => 'Medium',
        PdfPreset.high => 'High',
        PdfPreset.maximum => 'Maximum (smallest)',
      };
}

/// Compresses a PDF using Ghostscript (desktop only).
Future<PdfResult> compressPdf(
    String inputPath, String outputPath, PdfPreset preset) async {
  final stopwatch = Stopwatch()..start();
  final inputBytes = File(inputPath).lengthSync();
  final (ok, log) = await ExternalTools.run('gs', [
    '-sDEVICE=pdfwrite',
    '-dCompatibilityLevel=1.5',
    '-dPDFSETTINGS=${preset.gsSetting}',
    '-dNOPAUSE',
    '-dQUIET',
    '-dBATCH',
    '-sOutputFile=$outputPath',
    inputPath,
  ]);
  stopwatch.stop();
  if (!ok) {
    return PdfResult(success: false, error: 'Ghostscript failed:\n$log');
  }
  return PdfResult(
    success: true,
    inputBytes: inputBytes,
    outputBytes: File(outputPath).lengthSync(),
    elapsedMs: stopwatch.elapsedMilliseconds,
  );
}

/// Merges PDFs using qpdf when present, otherwise Ghostscript.
Future<PdfResult> mergePdfs(List<String> inputPaths, String outputPath) async {
  final stopwatch = Stopwatch()..start();
  final inputBytes =
      inputPaths.fold<int>(0, (sum, path) => sum + File(path).lengthSync());

  bool ok;
  String log;
  if (await ExternalTools.has('qpdf')) {
    (ok, log) = await ExternalTools.run(
        'qpdf', ['--empty', '--pages', ...inputPaths, '--', outputPath]);
  } else if (await ExternalTools.has('gs')) {
    (ok, log) = await ExternalTools.run('gs', [
      '-sDEVICE=pdfwrite',
      '-dNOPAUSE',
      '-dQUIET',
      '-dBATCH',
      '-sOutputFile=$outputPath',
      ...inputPaths,
    ]);
  } else {
    return const PdfResult(
        success: false,
        error: 'Merging needs qpdf or Ghostscript installed on this system.');
  }
  stopwatch.stop();
  if (!ok) return PdfResult(success: false, error: log);
  return PdfResult(
    success: true,
    inputBytes: inputBytes,
    outputBytes: File(outputPath).lengthSync(),
    elapsedMs: stopwatch.elapsedMilliseconds,
  );
}
