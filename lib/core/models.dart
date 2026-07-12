enum JobKind { image, pdf, video, audio, archive }

class HistoryEntry {
  final String fileName;
  final JobKind kind;
  final int inputBytes;
  final int outputBytes;
  final DateTime date;
  final int elapsedMs;

  const HistoryEntry({
    required this.fileName,
    required this.kind,
    required this.inputBytes,
    required this.outputBytes,
    required this.date,
    required this.elapsedMs,
  });

  Map<String, dynamic> toJson() => {
        'fileName': fileName,
        'kind': kind.name,
        'inputBytes': inputBytes,
        'outputBytes': outputBytes,
        'date': date.toIso8601String(),
        'elapsedMs': elapsedMs,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        fileName: json['fileName'] as String,
        kind: JobKind.values.asNameMap()[json['kind']] ?? JobKind.image,
        inputBytes: json['inputBytes'] as int,
        outputBytes: json['outputBytes'] as int,
        date: DateTime.parse(json['date'] as String),
        elapsedMs: json['elapsedMs'] as int? ?? 0,
      );
}

enum FileJobStatus { pending, running, done, failed }

/// UI-side status of one file inside a batch run.
class FileJob {
  final String inputPath;
  FileJobStatus status;
  String? outputPath;
  int inputBytes;
  int outputBytes;
  int elapsedMs;
  String? error;

  FileJob(this.inputPath)
      : status = FileJobStatus.pending,
        inputBytes = 0,
        outputBytes = 0,
        elapsedMs = 0;

  String get fileName => inputPath.split(RegExp(r'[/\\]')).last;
}
