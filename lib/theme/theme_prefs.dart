import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which theme the user picked. Deliberately a copy of [I18n]'s shape —
/// singleton ChangeNotifier over SharedPreferences, listened to by the
/// MaterialApp — so there is one pattern in this app for "a setting that
/// rebuilds everything", not two.
class ThemePrefs extends ChangeNotifier {
  static final ThemePrefs instance = ThemePrefs._();
  ThemePrefs._();

  static const _key = 'app_theme';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  /// Stored as a short string rather than the enum index: an index would
  /// silently change meaning if ThemeMode ever gained a value.
  static ThemeMode _parse(String? raw) => switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static String _encode(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };

  Future<void> load(SharedPreferences prefs) async {
    _mode = _parse(prefs.getString(_key));
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _encode(mode));
  }
}
