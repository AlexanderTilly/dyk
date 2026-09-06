import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palma_app/theme/dyk_theme.dart';

/// The theme is the app's colour contract. Screens that state no colour must
/// get a readable one from here — that is what lets the screen migration
/// delete colours rather than make every one of them conditional.
void main() {
  test('body text is ink on light and near-white on dark', () {
    expect(dykLightTheme().textTheme.bodyMedium!.color, PassimColors.ink);
    expect(dykDarkTheme().textTheme.bodyMedium!.color, PassimColors.onPhoto);
  });

  test('app bar follows the mode rather than staying navy', () {
    expect(dykLightTheme().appBarTheme.backgroundColor, PassimColors.sand);
    expect(dykLightTheme().appBarTheme.foregroundColor, PassimColors.ink);
    expect(dykDarkTheme().appBarTheme.backgroundColor, PassimColors.ink);
    expect(dykDarkTheme().appBarTheme.foregroundColor, PassimColors.onPhoto);
  });

  test('cards are white on light and raised navy on dark', () {
    expect(dykLightTheme().cardTheme.color, Colors.white);
    expect(dykDarkTheme().cardTheme.color, PassimColors.surface);
  });

  test('icons follow the mode', () {
    expect(dykLightTheme().iconTheme.color, PassimColors.ink);
    expect(dykDarkTheme().iconTheme.color, PassimColors.onPhoto);
  });

  test('onPhoto is white — it is white text, just named for its reason', () {
    expect(PassimColors.onPhoto, Colors.white);
  });
}
