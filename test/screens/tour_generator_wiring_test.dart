import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palma_app/screens/tour_generator_screen.dart';

Widget _host(TourGeneratorScreen s) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: s)));

TourGeneratorScreen _screen(
        FutureOr<void> Function(int, String, String) on,
        {String? notice}) =>
    TourGeneratorScreen(
        citypackId: 'palma',
        narratedCities: const {'palma'},
        onGenerate: on,
        notice: notice);

void main() {
  testWidgets('a second pull while the first future is pending is blocked',
      (t) async {
    var calls = 0;
    final done = Completer<void>();
    await t.pumpWidget(_host(_screen((a, b, c) {
      calls++;
      return done.future;
    })));
    await t.tap(find.byKey(const Key('lever')));
    await t.pump();
    await t.pump();
    await t.tap(find.byKey(const Key('lever')));
    await t.pump();
    expect(calls, 1);
    done.complete();
    await t.pump();
    await t.pump();
  });

  testWidgets('the notice shows beside the theme reel', (t) async {
    await t.pumpWidget(_host(_screen((a, b, c) {}, notice: 'too few')));
    expect(find.byKey(const Key('generator_notice')), findsOneWidget);
    expect(find.text('too few'), findsOneWidget);
  });

  testWidgets('the lever works again once the first future completes',
      (t) async {
    var calls = 0;
    final done = Completer<void>();
    await t.pumpWidget(_host(_screen((a, b, c) {
      calls++;
      return calls == 1 ? done.future : Future<void>.value();
    })));
    await t.tap(find.byKey(const Key('lever')));
    await t.pump();
    done.complete();
    await t.pump();
    await t.pump();
    await t.tap(find.byKey(const Key('lever')));
    await t.pump();
    expect(calls, 2);
  });

  testWidgets('a callback that throws does not escape and frees the lever',
      (t) async {
    var calls = 0;
    await t.pumpWidget(_host(_screen((a, b, c) async {
      calls++;
      throw StateError('boom');
    })));
    await t.tap(find.byKey(const Key('lever')));
    await t.pump();
    await t.pump();
    await t.tap(find.byKey(const Key('lever')));
    await t.pump();
    expect(calls, 2);
    expect(t.takeException(), isNull);
  });
}
