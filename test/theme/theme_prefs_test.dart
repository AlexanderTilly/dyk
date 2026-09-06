import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:palma_app/theme/theme_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to system when nothing is stored', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await ThemePrefs.instance.load(prefs);
    expect(ThemePrefs.instance.mode, ThemeMode.system);
  });

  test('restores a stored choice', () async {
    SharedPreferences.setMockInitialValues({'app_theme': 'light'});
    final prefs = await SharedPreferences.getInstance();
    await ThemePrefs.instance.load(prefs);
    expect(ThemePrefs.instance.mode, ThemeMode.light);
  });

  test('falls back to system on an unrecognised stored value', () async {
    SharedPreferences.setMockInitialValues({'app_theme': 'sepia'});
    final prefs = await SharedPreferences.getInstance();
    await ThemePrefs.instance.load(prefs);
    expect(ThemePrefs.instance.mode, ThemeMode.system);
  });

  test('setMode persists and notifies', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await ThemePrefs.instance.load(prefs);

    var notified = 0;
    void listener() => notified++;
    ThemePrefs.instance.addListener(listener);
    addTearDown(() => ThemePrefs.instance.removeListener(listener));

    await ThemePrefs.instance.setMode(ThemeMode.dark);

    expect(ThemePrefs.instance.mode, ThemeMode.dark);
    expect(notified, 1);
    expect(prefs.getString('app_theme'), 'dark');
  });
}
