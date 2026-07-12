import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/ffmpeg.dart';
import '../../core/format.dart';
import '../../core/history.dart';
import '../../core/models.dart';
import '../../core/output.dart';
import '../../core/settings.dart';
import '../../engines/image_engine.dart' show decodableExtensions;
import '../../engines/pdf_engine.dart';
import '../../widgets/file_drop_area.dart';

class PdfScreen extends ConsumerStatefulWidget {
  const PdfScreen({super.key});

  @override
  ConsumerState<PdfScreen> createState() => _PdfScreenState();
}

class _PdfScreenState extends ConsumerState<PdfScreen> {
  // Images → PDF
  final List<String> _images = [];
  bool _buildingPdf = false;

  // Compress / merge
  final List<String> _pdfs = [];
  PdfPreset _preset = PdfPreset.high;
  bool _working = false;

  String? _message;
  bool _messageIsError = false;
  String? _lastOutputPath;

  void _report(
    PdfResult result,
    String successVerb,
    String fileName, {
    String? outputPath,
    bool showSavings = true,
  }) {
    setState(() {
      if (result.success) {
        _message =
            '$successVerb ${formatBytes(result.inputBytes)} → '
            '${formatBytes(result.outputBytes)}'
            '${showSavings ? ' (${savedPercent(result.inputBytes, result.outputBytes).toStringAsFixed(1)}% saved)' : ''}';
        _messageIsError = false;
        _lastOutputPath = outputPath;
      } else {
        _message = result.error;
        _messageIsError = true;
        _lastOutputPath = null;
      }
    });
    if (result.success) {
      ref
          .read(historyProvider.notifier)
          .add(
            HistoryEntry(
              fileName: fileName,
              kind: JobKind.pdf,
              inputBytes: result.inputBytes,
              outputBytes: result.outputBytes,
              date: DateTime.now(),
              elapsedMs: result.elapsedMs,
            ),
          );
    }
  }

  Future<void> _makePdf() async {
    final settings = ref.read(settingsProvider);
    final output = resolveOutputPath(
      inputPath: _images.first,
      outputDirectory: await effectiveOutputDirectory(settings.outputDirectory),
      suffix: '',
      newExtension: 'pdf',
    );
    setState(() => _buildingPdf = true);
    final result = await compute(
      imagesToPdf,
      ImagesToPdfRequest(
        imagePaths: List.of(_images),
        outputPath: output,
        quality: settings.defaultQuality,
      ),
    );
    setState(() => _buildingPdf = false);
    _report(result, 'PDF created:', output.split('/').last,
        outputPath: output, showSavings: false);
  }

  Future<void> _compress() async {
    final settings = ref.read(settingsProvider);
    setState(() => _working = true);
    for (final pdf in List.of(_pdfs)) {
      final output = resolveOutputPath(
        inputPath: pdf,
        outputDirectory: await effectiveOutputDirectory(
          settings.outputDirectory,
        ),
      );
      final result = await compressPdf(pdf, output, _preset);
      _report(result, 'Compressed:', pdf.split('/').last, outputPath: output);
      if (!result.success) break;
    }
    setState(() => _working = false);
  }

  Future<void> _merge() async {
    final settings = ref.read(settingsProvider);
    final output = resolveOutputPath(
      inputPath: _pdfs.first,
      outputDirectory: await effectiveOutputDirectory(settings.outputDirectory),
      suffix: '_merged',
    );
    setState(() => _working = true);
    final result = await mergePdfs(_pdfs, output);
    setState(() => _working = false);
    _report(
      result,
      'Merged ${_pdfs.length} PDFs:',
      output.split('/').last,
      outputPath: output,
    );
  }

  @override
  Widget build(BuildContext context) {
    final gsAvailable = ref.watch(ghostscriptAvailableProvider).value ?? false;
    final qpdfAvailable = ref.watch(qpdfAvailableProvider).value ?? false;
    final scheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('PDF Tools'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Images → PDF'),
              Tab(text: 'Compress & Merge'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ---- Images → PDF ----
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FileDropArea(
                  allowedExtensions: decodableExtensions,
                  fileType: FileType.image,
                  label: 'Add images — one page per image',
                  onFiles: (paths) => setState(
                    () => _images.addAll(
                      paths.where((path) => !_images.contains(path)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < _images.length; i++)
                  ListTile(
                    dense: true,
                    leading: Text('${i + 1}.'),
                    title: Text(_images[i].split('/').last),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _images.removeAt(i)),
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _images.isEmpty || _buildingPdf ? null : _makePdf,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: Text(
                    _buildingPdf
                        ? 'Building…'
                        : 'Create PDF (${_images.length} pages)',
                  ),
                ),
                if (_message != null) _messageCard(scheme),
              ],
            ),
            // ---- Compress & merge ----
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!gsAvailable && !qpdfAvailable)
                  Card(
                    color: scheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        ExternalTools.isDesktop
                            ? 'PDF compression needs Ghostscript (and merging '
                                  'benefits from qpdf). Install with:\n'
                                  'sudo apt install ghostscript qpdf'
                            : 'PDF compression and merging are currently '
                                  'desktop-only features.',
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add PDFs'),
                  onPressed: () async {
                    final result = await FilePicker.pickFiles(
                      allowMultiple: true,
                      type: FileType.custom,
                      allowedExtensions: ['pdf'],
                    );
                    if (result == null) return;
                    setState(
                      () => _pdfs.addAll(
                        result.files
                            .map((f) => f.path)
                            .whereType<String>()
                            .where((path) => !_pdfs.contains(path)),
                      ),
                    );
                  },
                ),
                for (var i = 0; i < _pdfs.length; i++)
                  ListTile(
                    dense: true,
                    leading: Text('${i + 1}.'),
                    title: Text(_pdfs[i].split('/').last),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _pdfs.removeAt(i)),
                    ),
                  ),
                const SizedBox(height: 8),
                DropdownButtonFormField<PdfPreset>(
                  initialValue: _preset,
                  decoration: const InputDecoration(
                    labelText: 'Compression level',
                  ),
                  items: [
                    for (final p in PdfPreset.values)
                      DropdownMenuItem(value: p, child: Text(p.label)),
                  ],
                  onChanged: (v) =>
                      setState(() => _preset = v ?? PdfPreset.high),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _pdfs.isEmpty || _working || !gsAvailable
                            ? null
                            : _compress,
                        icon: const Icon(Icons.compress),
                        label: const Text('Compress'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed:
                            _pdfs.length < 2 ||
                                _working ||
                                (!gsAvailable && !qpdfAvailable)
                            ? null
                            : _merge,
                        icon: const Icon(Icons.merge),
                        label: const Text('Merge'),
                      ),
                    ),
                  ],
                ),
                if (_working)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (_message != null) _messageCard(scheme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageCard(ColorScheme scheme) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Card(
      color: _messageIsError
          ? scheme.errorContainer
          : scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _message!,
                style: TextStyle(
                  color: _messageIsError
                      ? scheme.onErrorContainer
                      : scheme.onSecondaryContainer,
                ),
              ),
            ),
            if (_lastOutputPath != null && Platform.isAndroid)
              IconButton(
                tooltip: 'Share',
                icon: Icon(
                  Icons.share,
                  color: scheme.onSecondaryContainer,
                  size: 20,
                ),
                onPressed: () => SharePlus.instance.share(
                  ShareParams(files: [XFile(_lastOutputPath!)]),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
