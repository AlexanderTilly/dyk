import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palma_app/theme/dyk_theme.dart';
import 'package:palma_app/widgets/passim_background.dart';

/// The dark wordmark is cream-coloured and vanishes on sand, so the asset has
/// to follow the theme rather than the screen remembering to ask.
void main() {
  String assetOf(WidgetTester tester) {
    final image = tester.widget<Image>(find.byType(Image));
    return (image.image as AssetImage).assetName;
  }

  Future<void> pump(WidgetTester tester, Brightness b,
      {bool wordmarkOnly = false}) async {
    await tester.pumpWidget(MaterialApp(
      theme: b == Brightness.dark ? dykDarkTheme() : dykLightTheme(),
      home: Scaffold(body: PassimLogo(wordmarkOnly: wordmarkOnly)),
    ));
    // MaterialApp wraps its theme in an AnimatedTheme (~200ms default), so a
    // single pump mid-transition can still report the previous brightness.
    // Settle it so the assertion sees the theme this pump actually asked for.
    await tester.pumpAndSettle();
  }

  testWidgets('uses the cream logo on dark', (tester) async {
    await pump(tester, Brightness.dark);
    expect(assetOf(tester), 'assets/images/passim_logo.png');
  });

  testWidgets('uses the blue logo on light', (tester) async {
    await pump(tester, Brightness.light);
    expect(assetOf(tester), 'assets/images/passim_logo_light.png');
  });

  testWidgets('wordmarkOnly drops the pin, per theme', (tester) async {
    await pump(tester, Brightness.dark, wordmarkOnly: true);
    expect(assetOf(tester), 'assets/images/passim_wordmark.png');
    await pump(tester, Brightness.light, wordmarkOnly: true);
    expect(assetOf(tester), 'assets/images/passim_wordmark_light.png');
  });
}
