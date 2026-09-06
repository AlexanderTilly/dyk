import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palma_app/theme/dyk_theme.dart';
import 'package:palma_app/widgets/passim_background.dart';

/// The wordmark drifted right on narrow phones and sat correctly on wide ones,
/// because AppBar clamps a centred title so it cannot overlap the leading
/// slot — and the city pill reserves 160 px there. Putting the logo in
/// flexibleSpace fixes it; these tests make sure it stays fixed.
///
/// PassimLogo now picks its asset image from the theme's brightness, so a
/// bare MaterialApp (light by default) only ever exercised one of the two
/// assets. Both themes get their own image with its own intrinsic size, so
/// centring has to be checked in both rather than assumed to carry over.
void main() {
  Widget harness(Brightness brightness) => MaterialApp(
        theme: brightness == Brightness.dark ? dykDarkTheme() : dykLightTheme(),
        home: Scaffold(
          appBar: AppBar(
            toolbarHeight: 64,
            leadingWidth: 160,
            leading: Container(width: 160, color: Colors.amber),
            flexibleSpace: const SafeArea(
              bottom: false,
              child: SizedBox(
                height: 64,
                child: Center(child: PassimLogo(height: 34)),
              ),
            ),
            actions: const [SizedBox(width: 54)],
          ),
          body: const SizedBox(),
        ),
      );

  for (final brightness in [Brightness.light, Brightness.dark]) {
    for (final width in [320.0, 360.0, 411.0, 480.0]) {
      testWidgets(
          'wordmark is centred at ${width.toInt()} dp wide (${brightness.name})',
          (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(harness(brightness));
        // MaterialApp animates a theme change via AnimatedTheme; settle so
        // the logo's asset (and therefore its intrinsic size) reflects the
        // theme this pump asked for rather than a mid-transition frame.
        await tester.pumpAndSettle();

        final logo = find.byType(PassimLogo);
        expect(logo, findsOneWidget);
        final centre = tester.getCenter(logo);
        expect(
          centre.dx,
          moreOrLessEquals(width / 2, epsilon: 0.5),
          reason: 'logo drifted off centre on a ${width.toInt()} dp screen',
        );
      });
    }
  }
}
