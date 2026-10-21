import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:palma_app/i18n/i18n.dart';
import 'package:palma_app/models/tour.dart';
import 'package:palma_app/screens/tabs/tours_tab.dart';
import 'package:palma_app/services/audio_service.dart';
import 'package:palma_app/services/auth_service.dart';
import 'package:palma_app/services/dyk_repository.dart';
import 'package:palma_app/services/tour_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repo implements DykRepositoryBase {
  final Set<String> cities;
  _Repo(this.cities);
  @override
  Future<Set<String>> loadGeneratorCities() async => cities;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Auth implements AuthService {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Audio implements AudioService {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

http.Response _round(String id) => http.Response(
    jsonEncode({
      'tour_id': 't$id',
      'title': 'x',
      'meters': 1760,
      'minutes': 50,
      'stops': [
        {'order_index': 0, 'hotspot_id': id, 'title': 'p', 'lat': 39.5, 'lng': 2.6}
      ],
      'geojson': null,
    }),
    200);

const _near = TourLocation((lat: 39.5696, lng: 2.6502));
final _lever = find.byKey(const Key('lever'));

Future<void> _mount(
  WidgetTester t, {
  Set<String> cities = const {'palma'},
  required http.Client client,
  Future<TourLocation> Function()? locate,
  void Function(Tour)? onTour,
}) async {
  SharedPreferences.setMockInitialValues({});
  t.view.physicalSize = const Size(900, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ToursTab(
        tours: const [],
        repo: _Repo(cities),
        authService: _Auth(),
        audioService: _Audio(),
        citypackId: 'palma',
        cityLat: 39.5696,
        cityLng: 2.6502,
        generator:
            TourGenerator(client: client, baseUrl: 'https://x', anonKey: 'k'),
        locate: locate ?? () async => _near,
        onGeneratedTour: onTour ?? (_) {},
      ),
    ),
  ));
  await t.pump();
  await t.pump();
}

bool _leverEnabled(WidgetTester t) =>
    t.widget<FilledButton>(_lever).onPressed != null;

void main() {
  testWidgets('the machine is hidden where the generator is unavailable',
      (t) async {
    await _mount(t, cities: {}, client: MockClient((r) async => _round('a')));
    expect(_lever, findsNothing);
  });

  testWidgets('the machine shows in a narrated city', (t) async {
    await _mount(t, client: MockClient((r) async => _round('a')));
    expect(_lever, findsOneWidget);
  });

  testWidgets('a stalled pull clears busy within the cap and tells the person',
      (t) async {
    await _mount(t,
        client: MockClient((r) async => _round('a')),
        locate: () => Completer<TourLocation>().future);
    await t.tap(_lever);
    await t.pump();
    expect(_leverEnabled(t), isFalse);
    await t.pump(const Duration(seconds: 29));
    await t.pump();
    await t.pump();
    expect(_leverEnabled(t), isTrue);
    expect(find.text(tr('tour_failed')), findsOneWidget);
  });

  testWidgets('round two excludes round one; only the last two rounds count',
      (t) async {
    final bodies = <Map>[];
    final ids = ['a', 'b', 'c'];
    await _mount(t, client: MockClient((r) async {
      bodies.add(jsonDecode(r.body) as Map);
      return _round(ids[(bodies.length - 1) % 3]);
    }));
    for (var i = 0; i < 4; i++) {
      await t.tap(_lever);
      await t.pumpAndSettle();
    }
    expect(bodies.map((b) => b['exclude']).toList(), [
      <String>[],
      ['a'],
      ['a', 'b'],
      ['b', 'c'],
    ]);
  });

  testWidgets('location refused: round still runs and the person is told',
      (t) async {
    var opened = 0;
    await _mount(t,
        client: MockClient((r) async => _round('a')),
        locate: () async => const TourLocation(null, LocationIssue.denied),
        onTour: (_) => opened++);
    await t.tap(_lever);
    await t.pumpAndSettle();
    expect(opened, 1);
    // The tab notice and the snack bar (which survives the route change).
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text(tr('tour_no_location')), findsNWidgets(2));
  });

  testWidgets('no connectivity says offline, not a generic failure',
      (t) async {
    await _mount(t,
        client: MockClient((r) async => throw const SocketException('x')));
    await t.tap(_lever);
    await t.pumpAndSettle();
    expect(find.text(tr('tour_offline')), findsOneWidget);
    expect(_leverEnabled(t), isTrue);
  });
}
