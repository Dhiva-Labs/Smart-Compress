import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class HistoryNotifier extends Notifier<List<HistoryEntry>> {
  static const _key = 'history.entries';
  static const _maxEntries = 500;

  SharedPreferences? _prefs;

  @override
  List<HistoryEntry> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    final prefs = _prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      state = list;
    } catch (_) {
      // Corrupt history is not worth crashing over; start fresh.
      state = const [];
    }
  }

  void add(HistoryEntry entry) {
    state = [entry, ...state].take(_maxEntries).toList();
    _save();
  }

  void clear() {
    state = const [];
    _save();
  }

  void _save() {
    _prefs?.setString(_key, jsonEncode(state.map((e) => e.toJson()).toList()));
  }
}

final historyProvider =
    NotifierProvider<HistoryNotifier, List<HistoryEntry>>(HistoryNotifier.new);

class HistoryStats {
  final int totalFiles;
  final int totalSaved;
  final JobKind? mostUsedKind;

  const HistoryStats(this.totalFiles, this.totalSaved, this.mostUsedKind);
}

final historyStatsProvider = Provider<HistoryStats>((ref) {
  final entries = ref.watch(historyProvider);
  var saved = 0;
  final counts = <JobKind, int>{};
  for (final e in entries) {
    saved += (e.inputBytes - e.outputBytes).clamp(0, e.inputBytes);
    counts[e.kind] = (counts[e.kind] ?? 0) + 1;
  }
  JobKind? top;
  var topCount = 0;
  counts.forEach((k, v) {
    if (v > topCount) {
      top = k;
      topCount = v;
    }
  });
  return HistoryStats(entries.length, saved, top);
});
