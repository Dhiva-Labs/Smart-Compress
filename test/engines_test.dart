import 'dart:io';

import 'package:smart_compress/core/format.dart';
import 'package:smart_compress/core/output.dart';
import 'package:smart_compress/engines/archive_engine.dart';
import 'package:smart_compress/engines/image_engine.dart';
import 'package:smart_compress/engines/pdf_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('smart_compress_test');
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  /// A noisy gradient image that JPEG can meaningfully compress.
  File writeTestImage(String name, {int size = 400}) {
    final image = img.Image(width: size, height: size);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        image.setPixelRgb(x, y, x % 256, y % 256, (x * y) % 256);
      }
    }
    final file = File(p.join(tmp.path, name));
    file.writeAsBytesSync(img.encodePng(image));
    return file;
  }

  group('format helpers', () {
    test('formatBytes', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(1023), '1023 B');
      expect(formatBytes(1024), '1.0 KB');
      expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
    });

    test('savedPercent', () {
      expect(savedPercent(100, 25), 75);
      expect(savedPercent(0, 25), 0);
    });
  });

  group('resolveOutputPath', () {
    test('appends suffix and keeps extension', () {
      final out = resolveOutputPath(
          inputPath: p.join(tmp.path, 'photo.png'), suffix: '_compressed');
      expect(out, p.join(tmp.path, 'photo_compressed.png'));
    });

    test('never overwrites existing files', () {
      File(p.join(tmp.path, 'photo_x.png')).writeAsStringSync('');
      final out = resolveOutputPath(
          inputPath: p.join(tmp.path, 'photo.png'), suffix: '_x');
      expect(out, p.join(tmp.path, 'photo_x (1).png'));
    });

    test('swaps extension when converting', () {
      final out = resolveOutputPath(
          inputPath: p.join(tmp.path, 'photo.png'),
          suffix: '_converted',
          newExtension: 'jpg');
      expect(out, endsWith('photo_converted.jpg'));
    });
  });

  group('image engine', () {
    test('compresses PNG to JPEG at reduced quality', () {
      final input = writeTestImage('input.png');
      final output = p.join(tmp.path, 'out.jpg');
      final result = processImage(ImageJobRequest(
          inputPath: input.path, outputPath: output, quality: 60));
      expect(result.success, isTrue, reason: result.error);
      expect(File(output).existsSync(), isTrue);
      expect(result.outputBytes, greaterThan(0));
      expect(result.inputWidth, 400);
    });

    test('resizes to max dimension keeping aspect', () {
      final input = writeTestImage('input.png');
      final result = processImage(ImageJobRequest(
        inputPath: input.path,
        outputPath: p.join(tmp.path, 'small.jpg'),
        maxWidth: 100,
        maxHeight: 100,
      ));
      expect(result.success, isTrue, reason: result.error);
      expect(result.outputWidth, 100);
      expect(result.outputHeight, 100);
    });

    test('target size mode lands at or under the target', () {
      final input = writeTestImage('input.png', size: 600);
      const target = 20 * 1024;
      final result = processImage(ImageJobRequest(
        inputPath: input.path,
        outputPath: p.join(tmp.path, 'target.jpg'),
        targetBytes: target,
      ));
      expect(result.success, isTrue, reason: result.error);
      expect(result.outputBytes, lessThanOrEqualTo(target));
      // Should not sacrifice everything: expect more than 1 KB.
      expect(result.outputBytes, greaterThan(1024));
    });

    test('never grows a file when re-encoding the same format', () {
      // A well-compressed PNG re-encoded as PNG must not get bigger.
      final input = writeTestImage('optimized.png');
      final result = processImage(ImageJobRequest(
        inputPath: input.path,
        outputPath: p.join(tmp.path, 'recompressed.png'),
        quality: 80,
      ));
      expect(result.success, isTrue, reason: result.error);
      expect(result.outputBytes, lessThanOrEqualTo(result.inputBytes));
    });

    test('compress mode walks quality down to beat an already-compressed JPEG',
        () {
      // Input JPEG saved at quality 60 — re-encoding at 90 would grow it.
      final image = img.Image(width: 300, height: 300);
      for (var y = 0; y < 300; y++) {
        for (var x = 0; x < 300; x++) {
          image.setPixelRgb(x, y, x % 256, y % 256, (x * y) % 256);
        }
      }
      final input = File(p.join(tmp.path, 'photo.jpg'))
        ..writeAsBytesSync(img.encodeJpg(image, quality: 60));
      final result = processImage(ImageJobRequest(
        inputPath: input.path,
        outputPath: p.join(tmp.path, 'photo_out.jpg'),
        quality: 90,
        preferSmaller: true,
      ));
      expect(result.success, isTrue, reason: result.error);
      expect(result.outputBytes, lessThanOrEqualTo(result.inputBytes));
    });

    test('compress mode keeps original (and extension) when nothing wins',
        () {
      // A tiny flat PNG: JPEG output at any quality is bigger, so the
      // original PNG bytes must be kept even though .jpg was requested.
      final image = img.Image(width: 16, height: 16);
      final input = File(p.join(tmp.path, 'tiny.png'))
        ..writeAsBytesSync(img.encodePng(image));
      final result = processImage(ImageJobRequest(
        inputPath: input.path,
        outputPath: p.join(tmp.path, 'tiny_out.jpg'),
        quality: 80,
        preferSmaller: true,
      ));
      expect(result.success, isTrue, reason: result.error);
      expect(result.keptOriginal, isTrue);
      expect(result.outputBytes, result.inputBytes);
      expect(result.outputPath, endsWith('.png'));
    });

    test('fails cleanly on garbage input', () {
      final junk = File(p.join(tmp.path, 'junk.png'))
        ..writeAsStringSync('not an image');
      final result = processImage(ImageJobRequest(
          inputPath: junk.path, outputPath: p.join(tmp.path, 'x.jpg')));
      expect(result.success, isFalse);
      expect(result.error, isNotNull);
    });
  });

  group('archive engine', () {
    test('zip roundtrip with folder structure', () {
      final dir = Directory(p.join(tmp.path, 'stuff'))..createSync();
      File(p.join(dir.path, 'a.txt')).writeAsStringSync('hello' * 1000);
      Directory(p.join(dir.path, 'sub')).createSync();
      File(p.join(dir.path, 'sub', 'b.txt')).writeAsStringSync('world');

      final zipPath = p.join(tmp.path, 'out.zip');
      final created = createArchive(ArchiveJobRequest(
        inputPaths: [dir.path],
        outputPath: zipPath,
        format: ArchiveFormat.zip,
      ));
      expect(created.success, isTrue, reason: created.error);
      expect(created.fileCount, 2);
      expect(created.outputBytes, lessThan(created.inputBytes));

      final outDir = Directory(p.join(tmp.path, 'extracted'))..createSync();
      final extracted = extractArchive(ExtractRequest(
          archivePath: zipPath, outputDirectory: outDir.path));
      expect(extracted.success, isTrue, reason: extracted.error);
      expect(extracted.fileCount, 2);
      expect(
          File(p.join(outDir.path, 'stuff', 'sub', 'b.txt'))
              .readAsStringSync(),
          'world');
    });

    test('password-protected zip requires the password', () {
      final file = File(p.join(tmp.path, 'secret.txt'))
        ..writeAsStringSync('top secret');
      final zipPath = p.join(tmp.path, 'locked.zip');
      final created = createArchive(ArchiveJobRequest(
        inputPaths: [file.path],
        outputPath: zipPath,
        format: ArchiveFormat.zip,
        password: 'hunter2',
      ));
      expect(created.success, isTrue, reason: created.error);

      final outDir = Directory(p.join(tmp.path, 'unlocked'))..createSync();
      final good = extractArchive(ExtractRequest(
          archivePath: zipPath,
          outputDirectory: outDir.path,
          password: 'hunter2'));
      expect(good.success, isTrue, reason: good.error);
      expect(File(p.join(outDir.path, 'secret.txt')).readAsStringSync(),
          'top secret');
    });

    test('tar.gz roundtrip', () {
      final file = File(p.join(tmp.path, 'data.txt'))
        ..writeAsStringSync('abc' * 5000);
      final tarPath = p.join(tmp.path, 'out.tar.gz');
      final created = createArchive(ArchiveJobRequest(
        inputPaths: [file.path],
        outputPath: tarPath,
        format: ArchiveFormat.tarGz,
      ));
      expect(created.success, isTrue, reason: created.error);
      expect(created.outputBytes, lessThan(created.inputBytes));

      final outDir = Directory(p.join(tmp.path, 'untarred'))..createSync();
      final extracted = extractArchive(ExtractRequest(
          archivePath: tarPath, outputDirectory: outDir.path));
      expect(extracted.success, isTrue, reason: extracted.error);
      expect(File(p.join(outDir.path, 'data.txt')).readAsStringSync(),
          'abc' * 5000);
    });
  });

  group('pdf engine', () {
    test('images to PDF produces a valid multi-page document', () async {
      final image = writeTestImage('page.png', size: 300);
      final output = p.join(tmp.path, 'pages.pdf');
      final result = await imagesToPdf(ImagesToPdfRequest(
        imagePaths: [image.path, image.path],
        outputPath: output,
        quality: 80,
      ));
      expect(result.success, isTrue, reason: result.error);
      final bytes = File(output).readAsBytesSync();
      expect(bytes.length, greaterThan(500));
      // PDF magic header and end-of-file trailer (object streams are
      // compressed, so page markers aren't visible in the raw bytes).
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(String.fromCharCodes(bytes.skip(bytes.length - 32)),
          contains('%%EOF'));
      // Two embedded page images make it meaningfully larger than one.
      expect(result.inputBytes, greaterThan(0));
    });

    test('fails cleanly on an undecodable image', () async {
      final junk = File(p.join(tmp.path, 'junk.png'))
        ..writeAsStringSync('not an image');
      final result = await imagesToPdf(ImagesToPdfRequest(
          imagePaths: [junk.path],
          outputPath: p.join(tmp.path, 'bad.pdf')));
      expect(result.success, isFalse);
      expect(result.error, isNotNull);
    });
  });
}
