import 'package:flutter_test/flutter_test.dart';
import 'package:palma_app/i18n/i18n.dart';

/// A key missing from a language does not throw — `tr()` falls back to
/// English — so the gap only surfaces when a user in that language reaches
/// the screen and reads half a sentence in the wrong tongue. That is exactly
/// what happened to the onboarding flow, and it is invisible to every other
/// test we have.
void main() {
  final english = translations['en']!;

  test('every supported language is present in the table', () {
    for (final code in I18n.supported) {
      expect(translations.containsKey(code), isTrue,
          reason: '$code is offered in Settings but has no strings');
    }
  });

  for (final code in I18n.supported.where((c) => c != 'en')) {
    test('$code has every key English has', () {
      final missing = english.keys
          .where((k) => !translations[code]!.containsKey(k))
          .toList()
        ..sort();
      expect(missing, isEmpty,
          reason: 'these fall back to English for $code users:\n'
              '${missing.join('\n')}');
    });

    test('$code has no keys English lacks', () {
      // The other direction matters too: a stray key is dead weight that
      // looks translated but can never be reached.
      final extra = translations[code]!
          .keys
          .where((k) => !english.containsKey(k))
          .toList()
        ..sort();
      expect(extra, isEmpty, reason: 'unreachable keys in $code: $extra');
    });

    test('$code is not silently copied from English', () {
      // A handful of words are legitimately identical across languages
      // ("Passim", "System", "OK"), so this only flags a suspicious bulk.
      final identical = english.keys
          .where((k) =>
              translations[code]![k] == english[k] && english[k]!.length > 12)
          .toList();
      expect(identical.length, lessThan(english.length ~/ 4),
          reason: '$code looks like untranslated English in ${identical.length} '
              'long strings: ${identical.take(10).join(', ')}');
    });
  }

  test('the app is called Passim, not DYK', () {
    // The rebrand left strings behind; Jose found them in onboarding.
    final offenders = <String>[];
    translations.forEach((code, map) {
      map.forEach((key, value) {
        if (value.contains('DYK') || value.contains('Did You Know')) {
          offenders.add('$code/$key: $value');
        }
      });
    });
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
