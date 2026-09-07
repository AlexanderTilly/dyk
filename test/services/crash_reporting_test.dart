import 'package:flutter_test/flutter_test.dart';
import 'package:palma_app/services/crash_reporting.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// This app follows people around a city, so a coordinate reaching a crash
/// report is a location leak — no matter how well-meant the log line that
/// produced it was. The scrubber is the only thing standing between the two,
/// which is why it is tested and the rest of the wiring is not.
void main() {
  final hint = Hint();

  Breadcrumb? scrub(Breadcrumb c) => dropLocationBreadcrumbs(c, hint);

  test('drops a breadcrumb whose message quotes coordinates', () {
    final crumb = Breadcrumb(
      message: 'presence recorded at lat 39.5696, lng 2.6502',
    );
    expect(scrub(crumb), isNull);
  });

  test('drops a breadcrumb categorised as location', () {
    expect(scrub(Breadcrumb(message: 'fix', category: 'geo.latitude')), isNull);
  });

  test('drops a breadcrumb carrying coordinates in its data', () {
    final crumb = Breadcrumb(
      message: 'hotspot entered',
      data: {'latitude': 39.5696, 'longitude': 2.6502},
    );
    expect(scrub(crumb), isNull);
  });

  test('drops a geolocator Position dump', () {
    expect(scrub(Breadcrumb(message: 'Position(39.5, 2.6)')), isNull);
  });

  test('keeps a breadcrumb with nothing positional in it', () {
    final crumb = Breadcrumb(message: 'audio playback started');
    expect(scrub(crumb), isNotNull);
  });

  test('keeps a breadcrumb about a hotspot by name, not by place', () {
    // Losing every crumb would make reports useless; only positions go.
    final crumb = Breadcrumb(
      message: 'opened hotspot',
      data: {'slug': '77', 'title': 'The Walled-In Lady of La Seu'},
    );
    expect(scrub(crumb), isNotNull);
  });

  test('a null breadcrumb stays null rather than throwing', () {
    expect(dropLocationBreadcrumbs(null, hint), isNull);
  });

  test('reporting is off unless the build was given a DSN', () {
    // Guards the default: a release built without the flag must still run,
    // silently unreported, rather than crash on launch for a missing key.
    expect(crashReportingEnabled, isFalse);
  });
}
