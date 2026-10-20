import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palma_app/screens/tour_generator_screen.dart';
import 'package:palma_app/widgets/reel.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('Reel', () {
    Widget reel(int value, List<int> log) => _host(Center(
          child: Reel<int>(
            values: const [1, 2, 3],
            value: value,
            onChanged: log.add,
            label: (v) => 'v$v',
          ),
        ));

    testWidgets('shows its current value', (t) async {
      await t.pumpWidget(reel(2, []));
      expect(find.text('v2'), findsOneWidget);
    });

    testWidgets('dragging up moves to the next value, once', (t) async {
      final log = <int>[];
      await t.pumpWidget(reel(2, log));
      await t.drag(find.byType(Reel<int>), const Offset(0, -80));
      expect(log, [3]);
    });

    testWidgets('dragging down moves to the previous value', (t) async {
      final log = <int>[];
      await t.pumpWidget(reel(2, log));
      await t.drag(find.byType(Reel<int>), const Offset(0, 80));
      expect(log, [1]);
    });

    Future<void> finger(WidgetTester t, double dy) async {
      final g = await t.startGesture(t.getCenter(find.byType(Reel<int>)));
      await g.moveBy(Offset(0, dy));
      await g.up();
      await t.pump();
    }

    testWidgets('a sub-threshold drag does nothing', (t) async {
      final log = <int>[];
      await t.pumpWidget(reel(2, log));
      await finger(t, -20);
      expect(log, isEmpty);
    });

    testWidgets('a finger swipe just past the threshold steps once', (t) async {
      final log = <int>[];
      await t.pumpWidget(reel(2, log));
      await finger(t, -30);
      expect(log, [3]);
    });

    testWidgets('a rebuild mid-drag does not lose the drag', (t) async {
      final log = <int>[];
      await t.pumpWidget(reel(2, log));
      final g = await t.startGesture(t.getCenter(find.byType(Reel<int>)));
      await g.moveBy(const Offset(0, -30));
      await t.pumpWidget(reel(2, log)); // rebuild, same value
      await g.moveBy(const Offset(0, -30));
      await g.up();
      expect(log, [3]);
    });

    testWidgets('does not wrap past either end', (t) async {
      final log = <int>[];
      await t.pumpWidget(reel(3, log));
      await t.drag(find.byType(Reel<int>), const Offset(0, -80));
      expect(log, isEmpty);
      await t.pumpWidget(reel(1, log));
      await t.drag(find.byType(Reel<int>), const Offset(0, 80));
      expect(log, isEmpty);
    });
  });

  group('TourGeneratorScreen', () {
    Future<void> pump(WidgetTester t,
        {void Function(int, String, String)? onGenerate,
        String? city = 'palma',
        Set<String> cities = const {'palma'}}) async {
      await t.pumpWidget(_host(TourGeneratorScreen(
        citypackId: city,
        narratedCities: cities,
        onGenerate: onGenerate ?? (_, __, ___) {},
      )));
    }

    Future<void> dragDistance(WidgetTester t, double dy) =>
        t.drag(find.byKey(const Key('reel_distance')), Offset(0, dy)).then((_) => t.pump());
    Future<void> dragTheme(WidgetTester t, double dy) =>
        t.drag(find.byKey(const Key('reel_theme')), Offset(0, dy)).then((_) => t.pump());

    testWidgets('hidden when the city is not narrated', (t) async {
      await pump(t, city: 'elsewhere');
      expect(find.byKey(const Key('reel_distance')), findsNothing);
    });

    testWidgets('walls_gates is absent below 5 km', (t) async {
      await pump(t);
      // Walk the rendered theme reel to its last entry.
      for (var i = 0; i < 10; i++) {
        await dragTheme(t, -80);
      }
      expect(find.text('Modernisme'), findsOneWidget);
      expect(find.text('Walls, gates & towers'), findsNothing);
      for (var i = 0; i < 10; i++) {
        await dragTheme(t, 80);
        expect(find.text('Walls, gates & towers'), findsNothing);
      }
      final state = t.state<TourGeneratorScreenState>(
          find.byType(TourGeneratorScreen));
      expect(state.distanceKm, 2);
      expect(state.availableThemes, isNot(contains('walls_gates')));
    });

    testWidgets('walls_gates is offered at 5 km', (t) async {
      await pump(t);
      final state = t.state<TourGeneratorScreenState>(
          find.byType(TourGeneratorScreen));
      await dragDistance(t, -80); // 2 -> 3
      await dragDistance(t, -80); // 3 -> 5
      expect(state.distanceKm, 5);
      expect(state.availableThemes, contains('walls_gates'));
    });

    for (final target in [3, 1]) {
      testWidgets(
          'walls_gates picked by dragging at 5 km falls back to palaces '
          'when distance drops to $target km', (t) async {
        final pulls = <List<Object>>[];
        await pump(t, onGenerate: (d, s, th) => pulls.add([d, s, th]));
        final state = t.state<TourGeneratorScreenState>(
            find.byType(TourGeneratorScreen));
        await dragDistance(t, -80);
        await dragDistance(t, -80);
        expect(state.distanceKm, 5);
        // food_drink -> churches -> ghosts -> walls_gates
        for (var i = 0; i < 3; i++) {
          await dragTheme(t, -80);
        }
        expect(state.theme, 'walls_gates');
        expect(find.text('Walls, gates & towers'), findsOneWidget);

        while (state.distanceKm > target) {
          await dragDistance(t, 80);
        }
        expect(state.theme, 'palaces');
        expect(find.text('Walls, gates & towers'), findsNothing);

        await t.tap(find.byKey(const Key('lever')));
        expect(pulls, hasLength(1));
        expect(pulls.single[0], target);
        expect(pulls.single[2], 'palaces');
      });
    }

    testWidgets('a double tap pulls once', (t) async {
      var n = 0;
      await pump(t, onGenerate: (_, __, ___) => n++);
      await t.tap(find.byKey(const Key('lever')));
      await t.tap(find.byKey(const Key('lever')));
      expect(n, 1);
      await t.pump();
      await t.pump();
      await t.tap(find.byKey(const Key('lever')));
      expect(n, 2);
    });

    testWidgets('busy disables the lever and shows the busy label',
        (t) async {
      var n = 0;
      await t.pumpWidget(_host(TourGeneratorScreen(
        citypackId: 'palma',
        narratedCities: const {'palma'},
        busy: true,
        onGenerate: (_, __, ___) => n++,
      )));
      await t.tap(find.byKey(const Key('lever')), warnIfMissed: false);
      expect(n, 0);
      expect(find.text('Cutting your tour...'), findsOneWidget);
    });

    testWidgets('lever reports the three reel values', (t) async {
      final pulls = <List<Object>>[];
      await pump(t, onGenerate: (d, s, th) => pulls.add([d, s, th]));
      await dragTheme(t, -80);
      await t.tap(find.byKey(const Key('lever')));
      expect(pulls.single[0], 2);
      expect(pulls.single[1], 'loop');
      expect(pulls.single[2], 'churches');
    });
  });
}
