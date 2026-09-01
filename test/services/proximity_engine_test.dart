import 'package:flutter_test/flutter_test.dart';
import 'package:palma_app/models/hot_deal.dart';
import 'package:palma_app/models/hotspot.dart';
import 'package:palma_app/services/proximity_engine.dart';

const _lat = 39.5674;
const _lng = 2.6486;

Hotspot _spot({String id = 'h1', String category = 'history', int radius = 20}) =>
    Hotspot(
      id: id,
      name: id,
      subtitle: '',
      description: '',
      lat: _lat,
      lng: _lng,
      radiusMeters: radius,
      audioFile: '',
      images: const [],
      year: '',
      category: category,
    );

HotDeal _deal({
  String id = 'd1',
  int radius = 300,
  int minSteps = 0,
  String onTour = 'exclude',
  List<int> days = const [],
  int from = 0,
  int to = 24,
  String arrival = 'any',
  String? interest,
}) =>
    HotDeal(
      id: id,
      businessName: 'Cafe',
      offerText: 'Two for one',
      lat: _lat,
      lng: _lng,
      radiusMeters: radius,
      minStepsToday: minSteps,
      targetOnTour: onTour,
      activeDays: days,
      activeHourFrom: from,
      activeHourTo: to,
      targetArrival: arrival,
      targetInterest: interest,
    );

const _all = {'history', 'otium', 'headline', 'hotdeal'};

List<ProximityHit> _check(
  ProximityEngine e, {
  double lat = _lat,
  double lng = _lng,
  List<Hotspot> hotspots = const [],
  List<HotDeal> deals = const [],
  Set<String> interests = _all,
  bool tourActive = false,
  int steps = 0,
  DateTime? now,
  DateTime? arrived,
}) =>
    e.check(
      lat: lat,
      lng: lng,
      hotspots: hotspots,
      deals: deals,
      interests: interests,
      tourActive: tourActive,
      stepsToday: steps,
      now: now,
      cityArrivedAt: arrived,
    );

void main() {
  group('hotspots', () {
    test('fires once on arrival, not again while standing there', () {
      final e = ProximityEngine();
      expect(_check(e, hotspots: [_spot()]), [const ProximityHit('hotspot', 'h1')]);
      expect(_check(e, hotspots: [_spot()]), isEmpty);
    });

    test('re-arms after leaving the radius and coming back', () {
      final e = ProximityEngine();
      _check(e, hotspots: [_spot()]);
      // ~200 m away: outside 20 m + 30 m buffer.
      _check(e, hotspots: [_spot()], lat: _lat + 0.002);
      expect(_check(e, hotspots: [_spot()]), hasLength(1));
    });

    test('stays quiet just outside the radius', () {
      final e = ProximityEngine();
      expect(_check(e, hotspots: [_spot()], lat: _lat + 0.001), isEmpty);
    });

    test('respects the interest filter', () {
      final e = ProximityEngine();
      expect(
        _check(e,
            hotspots: [_spot(category: 'otium')], interests: {'history'}),
        isEmpty,
      );
    });

    test('is muted while a tour is running', () {
      final e = ProximityEngine();
      expect(_check(e, hotspots: [_spot()], tourActive: true), isEmpty);
    });
  });

  group('deal targeting', () {
    test('fires for a plain deal in range', () {
      final e = ProximityEngine();
      expect(_check(e, deals: [_deal()]), [const ProximityHit('deal', 'd1')]);
    });

    test('needs the hotdeal interest', () {
      final e = ProximityEngine();
      expect(_check(e, deals: [_deal()], interests: {'history'}), isEmpty);
    });

    test('holds back until the step segment is met', () {
      final e = ProximityEngine();
      expect(_check(e, deals: [_deal(minSteps: 6000)], steps: 3000), isEmpty);
      expect(_check(e, deals: [_deal(minSteps: 6000)], steps: 6200), hasLength(1));
    });

    test('leaves people on a tour alone by default', () {
      final e = ProximityEngine();
      expect(_check(e, deals: [_deal()], tourActive: true), isEmpty);
    });

    test('can target only people on a tour', () {
      final e = ProximityEngine();
      expect(_check(e, deals: [_deal(onTour: 'only')]), isEmpty);
      expect(
        _check(e, deals: [_deal(onTour: 'only')], tourActive: true),
        hasLength(1),
      );
    });

    test('honours the hour window', () {
      final e = ProximityEngine();
      final morning = DateTime(2026, 9, 1, 9);
      final happyHour = DateTime(2026, 9, 1, 17);
      expect(_check(e, deals: [_deal(from: 16, to: 18)], now: morning), isEmpty);
      expect(
        _check(e, deals: [_deal(from: 16, to: 18)], now: happyHour),
        hasLength(1),
      );
    });

    test('honours weekdays, counting Sunday as 0', () {
      final e = ProximityEngine();
      final sunday = DateTime(2026, 8, 30); // a Sunday
      expect(_check(e, deals: [_deal(days: [1, 2])], now: sunday), isEmpty);
      expect(_check(e, deals: [_deal(days: [0])], now: sunday), hasLength(1));
    });

    test('just-arrived targeting needs an arrival within 24 h', () {
      final e = ProximityEngine();
      final now = DateTime(2026, 9, 1, 12);
      expect(_check(e, deals: [_deal(arrival: 'new')], now: now), isEmpty);
      expect(
        _check(e,
            deals: [_deal(arrival: 'new')],
            now: now,
            arrived: now.subtract(const Duration(days: 3))),
        isEmpty,
      );
      expect(
        _check(e,
            deals: [_deal(arrival: 'new')],
            now: now,
            arrived: now.subtract(const Duration(hours: 2))),
        hasLength(1),
      );
    });

    test('interest targeting matches the follower', () {
      final e = ProximityEngine();
      expect(
        _check(e,
            deals: [_deal(interest: 'otium')], interests: {'hotdeal', 'history'}),
        isEmpty,
      );
      expect(
        _check(e,
            deals: [_deal(interest: 'otium')], interests: {'hotdeal', 'otium'}),
        hasLength(1),
      );
    });
  });

  test('reports both a hotspot and a deal from one fix', () {
    final e = ProximityEngine();
    final hits = _check(e, hotspots: [_spot()], deals: [_deal()]);
    expect(hits, containsAll(const [
      ProximityHit('hotspot', 'h1'),
      ProximityHit('deal', 'd1'),
    ]));
  });
}
