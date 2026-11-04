import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Jose kept finding English words in the Spanish app, and each report fixed
/// one screen while the next feature added another. The translations map had
/// a parity test from the start — but parity only proves a key exists in four
/// languages, never that a widget bothered to call it. A literal in a
/// `Text(...)` passes every test we had.
///
/// This walks the widgets instead and fails on English prose that never
/// reaches i18n. It found eleven on the day it was written, nine of which
/// were real.
void main() {
  /// Things that are correctly not translated.
  const allowed = {
    'Passim', // the brand
    'support@diduknow.app', // an address, not prose — and still the live one
  };

  test('no English literals in user-facing Text widgets', () {
    final offenders = <String>[];
    final dirs = [Directory('lib/screens'), Directory('lib/widgets')];

    // Text('Some words') — a literal starting with a letter and long enough
    // to be prose rather than a symbol. Interpolations ($) are skipped: those
    // are usually a translated fragment plus a value.
    final literal = RegExp(r"""Text\(\s*'([A-Za-z][^'$]{3,})'""");

    for (final dir in dirs) {
      if (!dir.existsSync()) continue;
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final src = f.readAsStringSync();
        for (final m in literal.allMatches(src)) {
          final text = m.group(1)!;
          if (allowed.contains(text)) continue;
          // A line number makes the failure actionable rather than a riddle.
          final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
          offenders.add('${f.path}:$line  "$text"');
        }
      }
    }

    expect(offenders, isEmpty,
        reason: 'These read as English on a Spanish phone. Move them to '
            'lib/i18n/i18n.dart in all four languages, or add them to the '
            'allowed set above if they are names rather than prose.\n'
            '${offenders.join('\n')}');
  });
}
