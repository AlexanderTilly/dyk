import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:palma_app/models/themes.dart';
import 'package:palma_app/screens/tour_generator_screen.dart' show pullTimeout;
import 'package:palma_app/i18n/i18n.dart';
import 'package:palma_app/services/tour_generator.dart';

const _ok = {
  'tour_id': 't1',
  'title': 'Ghosts walk, 2 km',
  'meters': 1760,
  'minutes': 56,
  'stops': [
    {'order_index': 0, 'hotspot_id': 'h1', 'title': 'Catedral', 'lat': 39.567, 'lng': 2.648},
    {'order_index': 1, 'hotspot_id': 'h2', 'title': 'Almudaina', 'lat': 39.568, 'lng': 2.646},
  ],
  'geojson': {'type': 'LineString', 'coordinates': []},
};

TourGenerator _gen(MockClient c, {Duration? timeout}) => TourGenerator(
      client: c,
      baseUrl: 'https://x.supabase.co',
      anonKey: 'anon',
      timeout: timeout ?? tourRequestTimeout,
    );

Future<GeneratedTour> _call(TourGenerator g, {List<String> exclude = const []}) =>
    g.generate(
      lat: 39.5675,
      lng: 2.6485,
      km: 2,
      shape: 'loop',
      theme: 'ghosts',
      citypackId: 'palma',
      exclude: exclude,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  test('a normal reply parses, stops in order', () async {
    final g = _gen(MockClient((r) async => http.Response(
        jsonEncode(_ok), 200,
        headers: {'content-type': 'application/json'})));
    final t = await _call(g);
    expect(t.tourId, 't1');
    expect(t.meters, 1760);
    expect(t.minutes, 56);
    expect(t.stops.map((s) => s.hotspotId), ['h1', 'h2']);
    expect(t.stops.first.title, 'Catedral');
  });

  test('stops are sorted by order_index even if the reply is not', () async {
    final body = {
      ..._ok,
      'stops': (_ok['stops'] as List).reversed.toList(),
    };
    final g = _gen(MockClient((r) async => http.Response(jsonEncode(body), 200)));
    expect((await _call(g)).stops.map((s) => s.hotspotId), ['h1', 'h2']);
  });

  test('422 throws TourTooFew carrying the theme', () async {
    final g = _gen(MockClient((r) async => http.Response(
        jsonEncode({'error': 'too_few', 'theme': 'ghosts', 'message': 'm'}),
        422)));
    await expectLater(
        _call(g),
        throwsA(isA<TourTooFew>().having((e) => e.theme, 'theme', 'ghosts')));
  });

  test('other failures throw TourGenerationFailed', () async {
    for (final c in [
      MockClient((r) async => http.Response('{"error":"x"}', 500)),
      MockClient((r) async => http.Response('not json', 200)),
      MockClient((r) async => throw http.ClientException('offline')),
    ]) {
      await expectLater(_call(_gen(c)), throwsA(isA<TourGenerationFailed>()));
    }
  });

  test('a hung request fails at the 25 s timeout, not before and not after',
      () {
    expect(tourRequestTimeout, const Duration(seconds: 25));
    // The screen's latch is the backstop; it must outlast the network.
    expect(tourRequestTimeout < pullTimeout, isTrue);

    fakeAsync((fa) {
      final g = _gen(MockClient((r) => Completer<http.Response>().future));
      Object? error;
      unawaited(_call(g).then<void>((_) {}, onError: (Object e) {
        error = e;
      }));
      fa.elapse(const Duration(seconds: 24));
      expect(error, isNull);
      fa.elapse(const Duration(seconds: 1, milliseconds: 1));
      expect(error, isA<TourGenerationFailed>());
    });
  });

  test('sends the exclude list, the city and the anon key', () async {
    late http.Request seen;
    final g = _gen(MockClient((r) async {
      seen = r;
      return http.Response(jsonEncode(_ok), 200);
    }));
    await _call(g, exclude: ['a', 'b']);
    final body = jsonDecode(seen.body) as Map;
    expect(seen.url.toString(), 'https://x.supabase.co/functions/v1/generate-tour');
    expect(body['exclude'], ['a', 'b']);
    expect(body['citypack_id'], 'palma');
    expect(body['km'], 2);
    expect(body['shape'], 'loop');
    expect(body['theme'], 'ghosts');
    expect(seen.headers['apikey'], 'anon');
    expect(seen.headers['Authorization'], 'Bearer anon');
  });

  test('a reply with no stops is a failure, not a blank tour', () async {
    final body = {..._ok, 'stops': <Object>[]};
    final g = _gen(MockClient((r) async => http.Response(jsonEncode(body), 200)));
    await expectLater(_call(g), throwsA(isA<TourGenerationFailed>()));
  });

  test('no connectivity is flagged offline; a 500 is not', () async {
    for (final c in [
      MockClient((r) async => throw const SocketException('no route')),
      MockClient((r) async =>
          throw http.ClientException('SocketException: Failed host lookup')),
    ]) {
      await expectLater(
          _call(_gen(c)),
          throwsA(isA<TourGenerationFailed>()
              .having((e) => e.offline, 'offline', true)));
    }
    await expectLater(
        _call(_gen(MockClient((r) async => http.Response('{}', 500)))),
        throwsA(isA<TourGenerationFailed>()
            .having((e) => e.offline, 'offline', false)));
  });

  test('the whole-pull cap sits between the request and the latch', () {
    expect(tourRunTimeout > tourRequestTimeout, isTrue);
    expect(tourRunTimeout < pullTimeout, isTrue);
  });

  group('displayed title', () {
    GeneratedTour round() =>
        GeneratedTour.fromJson({..._ok, 'meters': 1820}, theme: 'ghosts');

    test('shows the measured distance, not the asked one or the server title',
        () {
      final t = round().toTour('palma');
      expect(t.title, contains('1.8 km'));
      expect(t.title, isNot(contains('2 km')));
      expect(t.distanceMeters, 1820);
    });

    test('the theme name is localised (German)', () async {
      await I18n.instance.setCode('de');
      addTearDown(() => I18n.instance.setCode('en'));
      final title = round().toTour('palma').title;
      expect(title, '${themeLabel('ghosts')}-Tour, 1.8 km');
      expect(title, contains('Geister'));
    });

    test('the reply theme wins over the requested one', () {
      final r = GeneratedTour.fromJson({..._ok, 'theme': 'churches'},
          theme: 'ghosts');
      expect(r.theme, 'churches');
    });
  });

  group('ExcludeHistory', () {
    test('starts empty and holds the previous round', () {
      final h = ExcludeHistory();
      expect(h.ids, isEmpty);
      h.add(['a', 'b']);
      expect(h.ids, ['a', 'b']);
    });

    test('keeps only the last two rounds', () {
      final h = ExcludeHistory();
      h.add(['a']);
      h.add(['b']);
      h.add(['c']);
      expect(h.ids, unorderedEquals(['b', 'c']));
      expect(ExcludeHistory.maxRounds, 2);
    });

    test('has no duplicates', () {
      final h = ExcludeHistory()..add(['a', 'b'])..add(['b', 'c']);
      expect(h.ids.toSet().length, h.ids.length);
    });
  });

  group('chooseTourStart', () {
    const centre = (lat: 39.5696, lng: 2.6502);
    test('a position near the centre is used as-is', () {
      const gps = (lat: 39.58, lng: 2.66);
      expect(chooseTourStart(gps, centre), gps);
    });
    test('a position far away is replaced by the centre', () {
      const home = (lat: 59.33, lng: 18.07);
      expect(chooseTourStart(home, centre), centre);
    });
    test('a GPS failure falls back to the centre', () {
      expect(chooseTourStart(null, centre), centre);
    });
    test('no centre known keeps the fix', () {
      const gps = (lat: 59.33, lng: 18.07);
      expect(chooseTourStart(gps, null), gps);
    });
  });
}
