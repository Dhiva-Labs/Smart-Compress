import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Formats we can write with the pure-Dart `image` package.
const encodableFormats = ['jpg', 'png', 'gif', 'bmp', 'tiff', 'ico'];

/// Formats we can read (decoding support is wider than encoding).
const decodableExtensions = [
  'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'tiff', 'tif', 'ico', 'tga',
  'psd', 'pnm',
];

class ImageJobRequest {
  final String inputPath;
  final String outputPath;

  /// 1–100. For JPEG this is encoder quality; for PNG it maps to the
  /// deflate level (higher quality = less aggressive compression).
  final int quality;
  final int? maxWidth;
  final int? maxHeight;

  /// When set, quality is searched automatically (JPEG output only) so the
  /// result lands at or just under this many bytes.
  final int? targetBytes;
  final bool stripMetadata;

  /// Compression intent: the result must be smaller than the input. If the
  /// first encode isn't, JPEG quality is walked down (to a floor of 40); if
  /// nothing beats the original, the original bytes are kept as-is.
  /// Off for format conversion, where growing is legitimate.
  final bool preferSmaller;

  const ImageJobRequest({
    required this.inputPath,
    required this.outputPath,
    this.quality = 80,
    this.maxWidth,
    this.maxHeight,
    this.targetBytes,
    this.stripMetadata = false,
    this.preferSmaller = false,
  });
}

class ImageJobResult {
  final bool success;
  final String? error;
  final String outputPath;
  final int inputBytes;
  final int outputBytes;
  final int inputWidth;
  final int inputHeight;
  final int outputWidth;
  final int outputHeight;
  final int elapsedMs;

  /// True when the input was already smaller than anything we could encode,
  /// so the original bytes were written unchanged.
  final bool keptOriginal;

  const ImageJobResult({
    required this.success,
    this.error,
    this.outputPath = '',
    this.inputBytes = 0,
    this.outputBytes = 0,
    this.inputWidth = 0,
    this.inputHeight = 0,
    this.outputWidth = 0,
    this.outputHeight = 0,
    this.elapsedMs = 0,
    this.keptOriginal = false,
  });
}

/// Top-level so it can run in a background isolate via `compute`.
ImageJobResult processImage(ImageJobRequest request) {
  final stopwatch = Stopwatch()..start();
  try {
    final inputBytes = File(request.inputPath).readAsBytesSync();
    var image = img.decodeImage(inputBytes);
    if (image == null) {
      return ImageJobResult(
          success: false,
          error: 'Unsupported or corrupt image: ${request.inputPath}');
    }
    final inputWidth = image.width;
    final inputHeight = image.height;
    var transformed = false;

    if (request.maxWidth != null || request.maxHeight != null) {
      final maxW = request.maxWidth ?? image.width;
      final maxH = request.maxHeight ?? image.height;
      if (image.width > maxW || image.height > maxH) {
        transformed = true;
        final scale =
            [maxW / image.width, maxH / image.height].reduce((a, b) => a < b ? a : b);
        image = img.copyResize(
          image,
          width: (image.width * scale).round().clamp(1, 1 << 16),
          interpolation: img.Interpolation.linear,
        );
      }
    }

    if (request.stripMetadata) {
      transformed = true;
      image.exif = img.ExifData();
    }

    final ext = request.outputPath.split('.').last.toLowerCase();
    Uint8List encoded;
    if (request.targetBytes != null && (ext == 'jpg' || ext == 'jpeg')) {
      final (bytes, resized) = _encodeJpegToTarget(image, request.targetBytes!);
      encoded = bytes;
      image = resized;
    } else {
      encoded = _encode(image, ext, request.quality);
    }

    final inputExt = request.inputPath.split('.').last.toLowerCase();
    final sameFormat = _normalizeExt(inputExt) == _normalizeExt(ext);
    var outputPath = request.outputPath;
    var keptOriginal = false;

    if (!transformed && encoded.length >= inputBytes.length) {
      // Re-encode didn't beat the source. In compress mode walk JPEG
      // quality down before giving up — camera JPEGs are often already
      // encoded near the requested quality.
      if (request.preferSmaller &&
          (ext == 'jpg' || ext == 'jpeg') &&
          request.targetBytes == null) {
        for (var q = request.quality - 10;
            q >= 40 && encoded.length >= inputBytes.length;
            q -= 10) {
          encoded = img.encodeJpg(image, quality: q);
        }
      }
      // Still no win: keep the original bytes (with the original extension,
      // which may differ when an un-encodable format was routed to JPEG).
      if ((sameFormat || request.preferSmaller) &&
          encoded.length >= inputBytes.length) {
        encoded = inputBytes;
        keptOriginal = true;
        if (!sameFormat) {
          outputPath = _uniquePath(
              '${outputPath.substring(0, outputPath.length - ext.length)}$inputExt');
        }
      }
    }

    File(outputPath).writeAsBytesSync(encoded);
    stopwatch.stop();
    return ImageJobResult(
      success: true,
      outputPath: outputPath,
      inputBytes: inputBytes.length,
      outputBytes: encoded.length,
      inputWidth: inputWidth,
      inputHeight: inputHeight,
      outputWidth: keptOriginal ? inputWidth : image.width,
      outputHeight: keptOriginal ? inputHeight : image.height,
      elapsedMs: stopwatch.elapsedMilliseconds,
      keptOriginal: keptOriginal,
    );
  } catch (e) {
    return ImageJobResult(success: false, error: '$e');
  }
}

String _normalizeExt(String ext) => switch (ext) {
      'jpeg' => 'jpg',
      'tif' => 'tiff',
      _ => ext,
    };

String _uniquePath(String path) {
  if (!File(path).existsSync()) return path;
  final dot = path.lastIndexOf('.');
  final stem = path.substring(0, dot);
  final ext = path.substring(dot);
  var counter = 1;
  while (File('$stem ($counter)$ext').existsSync()) {
    counter++;
  }
  return '$stem ($counter)$ext';
}

Uint8List _encode(img.Image image, String ext, int quality) {
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return img.encodeJpg(image, quality: quality.clamp(1, 100));
    case 'png':
      // PNG is lossless — deflate level trades speed for size, not quality,
      // so always use the strongest compression.
      return img.encodePng(image, level: 9);
    case 'gif':
      return img.encodeGif(image);
    case 'bmp':
      return img.encodeBmp(image);
    case 'tif':
    case 'tiff':
      return img.encodeTiff(image);
    case 'ico':
      return img.encodeIco(image);
    default:
      throw UnsupportedError('Cannot encode .$ext — supported outputs: '
          '${encodableFormats.join(', ')}');
  }
}

/// Binary-search JPEG quality so the encoded size lands at or below
/// [targetBytes] with the best quality that fits. If even quality 1 is too
/// large, the image is progressively downscaled until the target is
/// reachable. Returns the encoded bytes and the (possibly resized) image.
(Uint8List, img.Image) _encodeJpegToTarget(img.Image image, int targetBytes) {
  var current = image;
  var smallest = img.encodeJpg(current, quality: 1);
  // Downscale until quality 1 fits (or the image is already tiny).
  while (smallest.length > targetBytes && current.width > 64) {
    final ratio = targetBytes / smallest.length;
    // Bytes scale roughly with pixel count; shrink a bit extra for margin.
    final scale = (ratio * 0.9).clamp(0.3, 0.9);
    current = img.copyResize(
      current,
      width: (current.width * scale).round().clamp(64, current.width - 1),
      interpolation: img.Interpolation.linear,
    );
    smallest = img.encodeJpg(current, quality: 1);
  }
  if (smallest.length > targetBytes) return (smallest, current);

  var low = 1, high = 95;
  Uint8List? best;
  while (low <= high) {
    final mid = (low + high) ~/ 2;
    final candidate = img.encodeJpg(current, quality: mid);
    if (candidate.length <= targetBytes) {
      best = candidate;
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }
  return (best ?? smallest, current);
}
