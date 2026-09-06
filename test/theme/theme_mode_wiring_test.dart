import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:palma_app/theme/dyk_theme.dart';
import 'package:palma_app/theme/theme_prefs.dart';

/// main.dart wires MaterialApp.themeMode to ThemePrefs.instance.mode inside
/// an AnimatedBuilder over Listenable.merge([...]), so a change to the pref
/// is supposed to flip the whole app's brightness. Nothing asserted that
/// link directly — this reproduces the same wiring in miniature and checks
/// it end to end, rather than trusting that ThemePrefs notifying and
/// MaterialApp reading `themeMode` compose correctly.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('MaterialApp.themeMode follows ThemePrefs changes',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await ThemePrefs.instance.load(prefs);
    // Start from a known mode so the first assertion isn't at the mercy of
    // whatever the test host's platform brightness happens to be.
    await ThemePrefs.instance.setMode(ThemeMode.light);

    late BuildContext capturedContext;
    await tester.pumpWidget(
      AnimatedBuilder(
        animation: ThemePrefs.instance,
        builder: (context, _) => MaterialApp(
          theme: dykLightTheme(),
          darkTheme: dykDarkTheme(),
          themeMode: ThemePrefs.instance.mode,
          home: Builder(builder: (context) {
            capturedContext = context;
            return const Scaffold(body: SizedBox());
          }),
        ),
      ),
    );
    // MaterialApp animates a theme change via AnimatedTheme (~200ms), so
    // settle before reading brightness — a single pump can still report the
    // previous theme mid-transition.
    await tester.pumpAndSettle();

    expect(Theme.of(capturedContext).brightness, Brightness.light);

    await ThemePrefs.instance.setMode(ThemeMode.dark);
    await tester.pumpAndSettle();

    expect(Theme.of(capturedContext).brightness, Brightness.dark);
  });
}
