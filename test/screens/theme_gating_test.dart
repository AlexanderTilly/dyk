import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palma_app/i18n/i18n.dart';
import 'package:palma_app/models/themes.dart';
import 'package:palma_app/screens/tour_generator_screen.dart';
import 'package:palma_app/services/dyk_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _loadRoboto() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? 'C:/flutter/flutter';
  final loader = FontLoader('Roboto');
  for (final f in ['regular', 'black']) {
    final bytes = File('$root/bin/cache/artifacts/material_fonts/roboto-$f.ttf')
        .readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

Widget _host(Set<String>? cityThemes) => MaterialApp(
      home: Scaffold(
        body: TourGeneratorScreen(
          citypackId: 'palma',
          narratedCities: const {'palma'},
          cityThemes: cityThemes,
          onGenerate: (_, __, ___) {},
        ),
      ),
    );

/// "The sea & the harbour" had two tagged places in Palma on 2026-11-05.
/// selectPlaces needs three, so that position on the wheel returned nothing
/// from every start and every distance — the design's own anti-goal, live.
/// A theme now has to earn its place on the wheel, and earns it back by
/// itself when someone tags two more.
void main() {
  group('generator_themes rows → the set', () {
    test('keeps the theme keys', () {
      expect(
        generatorThemesFromRows([
          {'theme': 'ghosts', 'place_count': 15},
          {'theme': 'churches', 'place_count': 19},
        ]),
        {'ghosts', 'churches'},
      );
    });

    test('skips rows with no usable theme rather than inventing one', () {
      expect(
        generatorThemesFromRows([
          {'theme': 'ghosts'},
          {'theme': null},
          {'theme': ''},
          {'nope': 1},
          'not a map',
        ]),
        {'ghosts'},
      );
    });
  });

  group('the gate fails open', () {
    test('an unreadable view yields null, which means show everything',
        () async {
      expect(
        await generatorThemesFrom(() async => throw Exception('no view yet')),
        isNull,
      );
    });

    test('a readable but empty view yields an empty set, not null', () async {
      // The difference matters: null is "could not tell", empty is "this city
      // has nothing worth offering". They lead to opposite screens.
      expect(await generatorThemesFrom(() async => const []), isEmpty);
    });
  });

  group('the wheel', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> pump(WidgetTester t, Set<String>? cityThemes) async {
      await I18n.instance.load(await SharedPreferences.getInstance());
      await _loadRoboto();
      await t.pumpWidget(_host(cityThemes));
      await t.pump();
    }

    testWidgets('shows only the themes the city has places for', (t) async {
      await pump(t, {'ghosts', 'churches'});
      final state =
          t.state<TourGeneratorScreenState>(find.byType(TourGeneratorScreen));
      expect(state.availableThemes, ['churches', 'ghosts'],
          reason: 'in tourThemes order, not the order the view returned');
    });

    testWidgets('shows every theme when the city list is unknown', (t) async {
      await pump(t, null);
      final state =
          t.state<TourGeneratorScreenState>(find.byType(TourGeneratorScreen));
      // walls_gates is held back below 5 km by its own older rule.
      expect(state.availableThemes.length, tourThemes.length - 1);
    });

    testWidgets('a city with no qualifying theme shows no machine at all',
        (t) async {
      await pump(t, <String>{});
      expect(find.byType(TourGeneratorScreen), findsOneWidget);
      expect(find.text(tr('generate_tour')), findsNothing,
          reason: 'an empty wheel is worse than no wheel');
    });

    testWidgets('a selected theme that leaves the list is replaced', (t) async {
      // Opens on tourThemes.first; the city then turns out not to have it.
      await pump(t, null);
      final state =
          t.state<TourGeneratorScreenState>(find.byType(TourGeneratorScreen));
      expect(state.theme, tourThemes.first);

      await t.pumpWidget(_host({'ghosts'}));
      await t.pump();
      expect(state.theme, 'ghosts',
          reason: 'a selection that can only answer too_few must not survive');
    });
  });
}
