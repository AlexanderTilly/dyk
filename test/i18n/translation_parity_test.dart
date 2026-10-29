import 'dart:io';

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

  // The same check, one file further out. The rebrand test above watches the
  // translations map; Info.plist is the copy nobody was watching, and it still
  // read "Did You Know?" on 2026-10-29 — in the iOS permission dialogs, which
  // is the most sensitive text the app ever shows.
  test('iOS permission strings are branded Passim too', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist.contains('DYK'), isFalse,
        reason: 'stale branding in ios/Runner/Info.plist');
    expect(plist.contains('Did You Know'), isFalse,
        reason: 'stale branding in ios/Runner/Info.plist');
  });

  // Apple rejects the upload when the binary links an API with no purpose
  // string (error 90683). Build 1.4.1 (9) was turned away for exactly this:
  // the camera package arrived with the AR screen and nobody added the key.
  // Apple scans the binary, not the code path, so a demo screen still counts.
  test('every sensitive API the app links has a purpose string', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    const needs = {
      'camera': 'NSCameraUsageDescription',
      'geolocator': 'NSLocationWhenInUseUsageDescription',
      'image_picker': 'NSPhotoLibraryUsageDescription',
      'record': 'NSMicrophoneUsageDescription',
      'mobile_scanner': 'NSCameraUsageDescription',
    };

    final missing = <String>[];
    needs.forEach((package, key) {
      final declared = RegExp('^  $package:', multiLine: true).hasMatch(pubspec);
      if (declared && !plist.contains(key)) missing.add('$package needs $key');
    });

    expect(missing, isEmpty, reason: missing.join(', '));
  });
}
