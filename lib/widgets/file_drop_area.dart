import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

/// A pick-files card that also accepts drag-and-drop on desktop.
///
/// [fileType] drives the platform picker filter (so Android only shows
/// images/videos/audio when asked); [allowedExtensions] is enforced on top
/// of that for everything that comes in, including drops.
class FileDropArea extends StatefulWidget {
  final List<String>? allowedExtensions;
  final FileType fileType;
  final bool allowMultiple;
  final String label;
  final ValueChanged<List<String>> onFiles;

  const FileDropArea({
    super.key,
    required this.onFiles,
    this.allowedExtensions,
    this.fileType = FileType.any,
    this.allowMultiple = true,
    this.label = 'Drop files here or click to browse',
  });

  @override
  State<FileDropArea> createState() => _FileDropAreaState();
}

class _FileDropAreaState extends State<FileDropArea> {
  bool _hovering = false;

  bool get _isDesktop =>
      Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  /// Filters to the allowed extensions and reports skipped files.
  void _accept(List<String> paths) {
    final allowed = widget.allowedExtensions;
    var accepted = paths;
    if (allowed != null) {
      accepted = paths
          .where((path) =>
              allowed.contains(path.split('.').last.toLowerCase()))
          .toList();
      final skipped = paths.length - accepted.length;
      if (skipped > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Skipped $skipped unsupported file${skipped == 1 ? '' : 's'}')));
      }
    }
    if (!widget.allowMultiple && accepted.length > 1) {
      accepted = [accepted.first];
    }
    if (accepted.isNotEmpty) widget.onFiles(accepted);
  }

  Future<void> _browse() async {
    // Media types map to the platform's native filter (Android shows only
    // that media kind); otherwise fall back to extension filtering.
    final type = widget.fileType != FileType.any
        ? widget.fileType
        : (widget.allowedExtensions != null ? FileType.custom : FileType.any);
    final result = await FilePicker.pickFiles(
      allowMultiple: widget.allowMultiple,
      type: type,
      allowedExtensions:
          type == FileType.custom ? widget.allowedExtensions : null,
    );
    if (result == null) return;
    _accept(result.files
        .map((f) => f.path)
        .whereType<String>()
        .toList(growable: false));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final card = InkWell(
      onTap: _browse,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: _hovering
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          border: Border.all(
            color: _hovering ? scheme.primary : scheme.outlineVariant,
            width: _hovering ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(Icons.upload_file, size: 36, color: scheme.primary),
            const SizedBox(height: 10),
            Text(
              _isDesktop
                  ? widget.label
                  : widget.label
                      .replaceFirst('Drop files here or click', 'Tap'),
              textAlign: TextAlign.center,
            ),
            if (widget.allowedExtensions != null) ...[
              const SizedBox(height: 6),
              Text(
                widget.allowedExtensions!.join(' · ').toUpperCase(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
    );

    if (!_isDesktop) return card;
    return DropTarget(
      onDragEntered: (_) => setState(() => _hovering = true),
      onDragExited: (_) => setState(() => _hovering = false),
      onDragDone: (details) {
        setState(() => _hovering = false);
        _accept(details.files.map((f) => f.path).toList());
      },
      child: card,
    );
  }
}
