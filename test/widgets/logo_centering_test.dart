import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palma_app/widgets/passim_background.dart';

/// The wordmark drifted right on narrow phones and sat correctly on wide ones,
/// because AppBar clamps a centred title so it cannot overlap the leading
/// slot — and the city pill reserves 160 px there. Putting the logo in
/// flexibleSpace fixes it; these tests make sure it stays fixed.
void main() {
  Widget harness() => MaterialApp(
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

  for (final width in [320.0, 360.0, 411.0, 480.0]) {
    testWidgets('wordmark is centred at ${width.toInt()} dp wide',
        (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness());

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
