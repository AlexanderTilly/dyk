import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palma_app/theme/dyk_theme.dart';

/// Files that have been through the light-mode migration. A literal white in
/// one of these is a regression: the rule is that every white is either
/// deleted, so the colour is inherited, or named PassimColors.onPhoto so it
/// states why it is deliberate.
///
/// This list grows as screens are migrated. It is what makes an otherwise
/// unmeasurable 195-site job finishable — a file on this list is reviewed.
const migratedFiles = [
  'lib/widgets/passim_background.dart',
  'lib/widgets/passim_nav_bar.dart',
  'lib/screens/splash_screen.dart',
  'lib/theme/dyk_theme.dart',
  'lib/screens/premium_screen.dart',
  'lib/screens/welcome_city_screen.dart',
];

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
    expect(dykLightTheme().cardTheme.color, PassimColors.card);
    expect(dykDarkTheme().cardTheme.color, PassimColors.surface);
  });

  test('icons follow the mode', () {
    expect(dykLightTheme().iconTheme.color, PassimColors.ink);
    expect(dykDarkTheme().iconTheme.color, PassimColors.onPhoto);
  });

  test('onPhoto is white — it is white text, just named for its reason', () {
    expect(PassimColors.onPhoto, Colors.white);
  });

  test('migrated files use onPhoto, never a literal white', () {
    final offenders = <String>[];
    for (final path in migratedFiles) {
      final lines = File(path).readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // The palette itself has to name the literal once, for each
        // deliberate white it defines.
        if (path.endsWith('dyk_theme.dart') &&
            (line.contains('onPhoto =') || line.contains('card ='))) {
          continue;
        }
        if (line.contains('Colors.white')) {
          offenders.add('$path:${i + 1}: ${line.trim()}');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'use PassimColors.onPhoto, or delete the colour so the '
            'theme supplies it:\n${offenders.join('\n')}');
  });
}
