import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings {
  final ThemeMode themeMode;
  final int defaultQuality;
  final String? outputDirectory; // null = same folder as source
  final bool keepOriginals;
  final String outputSuffix;

  const Settings({
    this.themeMode = ThemeMode.system,
    this.defaultQuality = 80,
    this.outputDirectory,
    this.keepOriginals = true,
    this.outputSuffix = '_compressed',
  });

  Settings copyWith({
    ThemeMode? themeMode,
    int? defaultQuality,
    String? outputDirectory,
    bool clearOutputDirectory = false,
    bool? keepOriginals,
    String? outputSuffix,
  }) =>
      Settings(
        themeMode: themeMode ?? this.themeMode,
        defaultQuality: defaultQuality ?? this.defaultQuality,
        outputDirectory: clearOutputDirectory
            ? null
            : (outputDirectory ?? this.outputDirectory),
        keepOriginals: keepOriginals ?? this.keepOriginals,
        outputSuffix: outputSuffix ?? this.outputSuffix,
      );
}

class SettingsNotifier extends Notifier<Settings> {
  static const _keyTheme = 'settings.themeMode';
  static const _keyQuality = 'settings.defaultQuality';
  static const _keyOutputDir = 'settings.outputDirectory';
  static const _keyKeepOriginals = 'settings.keepOriginals';

  SharedPreferences? _prefs;

  @override
  Settings build() {
    _load();
    return const Settings();
  }

  Future<void> _load() async {
    final prefs = _prefs = await SharedPreferences.getInstance();
    state = Settings(
      themeMode: ThemeMode.values.asNameMap()[prefs.getString(_keyTheme)] ??
          ThemeMode.system,
      defaultQuality: prefs.getInt(_keyQuality) ?? 80,
      outputDirectory: prefs.getString(_keyOutputDir),
      keepOriginals: prefs.getBool(_keyKeepOriginals) ?? true,
    );
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _prefs?.setString(_keyTheme, mode.name);
  }

  void setDefaultQuality(int quality) {
    state = state.copyWith(defaultQuality: quality);
    _prefs?.setInt(_keyQuality, quality);
  }

  void setOutputDirectory(String? dir) {
    state = state.copyWith(outputDirectory: dir, clearOutputDirectory: dir == null);
    if (dir == null) {
      _prefs?.remove(_keyOutputDir);
    } else {
      _prefs?.setString(_keyOutputDir, dir);
    }
  }

  void setKeepOriginals(bool keep) {
    state = state.copyWith(keepOriginals: keep);
    _prefs?.setBool(_keyKeepOriginals, keep);
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, Settings>(SettingsNotifier.new);
