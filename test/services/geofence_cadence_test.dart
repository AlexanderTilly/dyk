import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:palma_app/services/geofence_task_handler.dart';

// ~1 m of latitude in degrees; lets tests place fences at exact distances.
const _mLat = 1 / 111195.0;

final _noon = DateTime(2026, 11, 4, 12);
const _lat = 39.57;
const _lng = 2.65;

/// A hotspot whose rim is [edgeM] metres due north of the user.
FenceCircle _fenceAtEdge(double edgeM, {double r = 20, bool fine = true}) =>
    FenceCircle(_lat + (edgeM + r) * _mLat, _lng, r, fine: fine);

PollPlan _plan(
  List<FenceCircle> f, {
  double acc = 10,
  DateTime? now,
  Duration still = Duration.zero,
  double speed = 0,
}) =>
    planNextFix(
        lat: _lat,
        lng: _lng,
        accuracyM: acc,
        fences: f,
        now: now ?? _noon,
        stillFor: still,
        observedSpeedMps: speed);

void main() {
  group('planNextFix: near behaves as today', () {
    test('no fences -> 12 s high', () {
      final p = _plan([]);
      expect(p.regime, PollRegime.near);
      expect(p.interval, kHeartbeat);
      expect(p.accuracy, LocationAccuracy.high);
    });

    test('inside a zone -> 12 s high', () {
      final p = _plan([_fenceAtEdge(-15)]);
      expect(p.regime, PollRegime.near);
      expect(p.accuracy, LocationAccuracy.high);
    });

    test('inside a zone stays near after hours of stillness at night', () {
      final p = _plan([_fenceAtEdge(-15)],
          still: const Duration(hours: 5), now: DateTime(2026, 11, 4, 3));
      expect(p.regime, PollRegime.near);
      expect(p.interval, kHeartbeat);
    });

    test('a resting phone close to a zone is not relaxed', () {
      final p = _plan([_fenceAtEdge(200)], still: const Duration(hours: 2));
      expect(p.regime, PollRegime.near);
    });
  });

  group('planNextFix: the far/near boundary', () {
    // acc 10 -> e = 100 (floor). near iff edge - 100 < 150 + 3*12 = 286.
    const boundary = 286.0;

    test('just inside the boundary is near', () {
      expect(_plan([_fenceAtEdge(boundary - 1)]).regime, PollRegime.near);
    });

    test('just outside is far, medium accuracy, at least one heartbeat', () {
      final p = _plan([_fenceAtEdge(boundary + 2)]);
      expect(p.regime, PollRegime.far);
      expect(p.accuracy, LocationAccuracy.medium);
      expect(p.interval, greaterThanOrEqualTo(kHeartbeat));
    });

    test('interval matches (d - e - g) / v, capped', () {
      // edge 1000: (1000 - 100 - 150) / 3 = 250 s -> capped to 180 s.
      expect(_plan([_fenceAtEdge(1000)]).interval, kFarCap);
      // edge 500: (500 - 250) / 3 = 83 s.
      expect(_plan([_fenceAtEdge(500)]).interval.inSeconds, closeTo(83, 1));
    });

    test('cap is respected for a very distant user', () {
      expect(_plan([_fenceAtEdge(20000)]).interval, kFarCap);
    });

    test('invariant: at the next fix the fastest walker is still outside '
        'the guard, at every distance', () {
      for (var edge = 280.0; edge < 5000; edge += 7) {
        final p = _plan([_fenceAtEdge(edge)]);
        if (p.regime == PollRegime.near) continue;
        final worstCase =
            edge - 100 - kWalkBoundMps * p.interval.inSeconds;
        expect(worstCase, greaterThanOrEqualTo(kGuardM - 3),
            reason: 'edge=$edge interval=${p.interval}');
      }
    });

    test('a poor fix widens the near zone (error is believed)', () {
      expect(_plan([_fenceAtEdge(600)]).regime, PollRegime.far);
      expect(_plan([_fenceAtEdge(600)], acc: 400).regime, PollRegime.near);
    });

    test('the nearest of many fences decides', () {
      final p =
          _plan([_fenceAtEdge(5000), _fenceAtEdge(100), _fenceAtEdge(3000)]);
      expect(p.regime, PollRegime.near);
    });

    test('walking in at the speed bound: far flips to near before the rim', () {
      var edge = 2000.0;
      var sawNear = false;
      for (var i = 0; i < 5000 && edge > 0; i++) {
        final p = _plan([_fenceAtEdge(edge)]);
        if (p.regime == PollRegime.near) {
          sawNear = true;
          expect(edge, greaterThan(kGuardM));
          break;
        }
        edge -= p.interval.inSeconds * kWalkBoundMps;
      }
      expect(sawNear, isTrue);
    });
  });

  group('planNextFix: speed', () {
    test('a fast phone shortens the interval and widens the near zone', () {
      final walk = _plan([_fenceAtEdge(1500)]);
      final car = _plan([_fenceAtEdge(1500)], speed: 15);
      expect(car.interval, lessThan(walk.interval));
      expect(_plan([_fenceAtEdge(450)], speed: 15).regime, PollRegime.near);
      expect(_plan([_fenceAtEdge(450)]).regime, PollRegime.far);
    });

    test('observed speed never lowers the walking bound', () {
      expect(_plan([_fenceAtEdge(500)], speed: 0.2).interval.inSeconds, closeTo(83, 1));
    });
  });

  group('planNextFix: rest', () {
    test('long stillness lifts the cap, not the geometry', () {
      final far = _plan([_fenceAtEdge(20000)], still: const Duration(hours: 1));
      expect(far.regime, PollRegime.rest);
      expect(far.interval, kStillCap);
      final mid = _plan([_fenceAtEdge(1000)], still: const Duration(hours: 1));
      expect(mid.interval.inSeconds, closeTo(250, 1));
    });

    test('a short stillness (reading a plaque) does not rest', () {
      final p = _plan([_fenceAtEdge(20000)], still: const Duration(minutes: 8));
      expect(p.regime, PollRegime.far);
      expect(p.interval, kFarCap);
    });

    test('night + stillness gets the longest cap', () {
      final p = _plan([_fenceAtEdge(50000)],
          still: const Duration(hours: 3), now: DateTime(2026, 11, 4, 3));
      expect(p.interval, kNightCap);
    });

    test('night without stillness does not rest', () {
      final p = _plan([_fenceAtEdge(50000)], now: DateTime(2026, 11, 4, 3));
      expect(p.interval, kFarCap);
    });

    test('daytime stillness is not given the night cap', () {
      final p = _plan([_fenceAtEdge(50000)], still: const Duration(hours: 3));
      expect(p.interval, kStillCap);
    });
  });

  group('planNextFix: city welcome', () {
    test('a not-yet-greeted city bounds the interval but allows coarse', () {
      // City rim 400 m away: (400 - 100) / 3 = 100 s.
      final p = _plan([
        _fenceAtEdge(30000),
        _fenceAtEdge(400, r: 1000, fine: false),
      ]);
      expect(p.regime, PollRegime.far);
      expect(p.interval.inSeconds, closeTo(100, 1));
      expect(p.accuracy, LocationAccuracy.medium);
    });

    test('a close city rim never forces high accuracy', () {
      final p = _plan([_fenceAtEdge(30000), _fenceAtEdge(50, fine: false)]);
      expect(p.accuracy, LocationAccuracy.medium);
      expect(p.interval, kHeartbeat);
    });
  });

  group('trackStillness', () {
    test('stays anchored under jitter, resets on real movement', () {
      final t0 = _noon;
      var a = trackStillness(null, _lat, _lng, 10, t0);
      a = trackStillness(a, _lat + 30 * _mLat, _lng, 10,
          t0.add(const Duration(minutes: 10)));
      expect(a.since, t0);
      a = trackStillness(a, _lat + 200 * _mLat, _lng, 10,
          t0.add(const Duration(minutes: 11)));
      expect(a.since, t0.add(const Duration(minutes: 11)));
    });

    test('the anchor does not drift, so a slow walk escapes', () {
      final t0 = _noon;
      var a = trackStillness(null, _lat, _lng, 10, t0);
      for (var i = 1; i <= 5; i++) {
        a = trackStillness(a, _lat + 20.0 * i * _mLat, _lng, 10,
            t0.add(Duration(minutes: i)));
      }
      expect(a.since.isAfter(t0), isTrue);
    });

    test('a poor fix widens the circle', () {
      final t0 = _noon;
      var a = trackStillness(null, _lat, _lng, 10, t0);
      a = trackStillness(a, _lat + 150 * _mLat, _lng, 200,
          t0.add(const Duration(minutes: 5)));
      expect(a.since, t0);
    });
  });

  group('stepMetresToCount', () {
    double steps(double d, double s, {double acc = 8, double last = 8}) =>
        stepMetresToCount(
            distanceM: d,
            elapsedSeconds: s,
            accuracyM: acc,
            lastAccuracyM: last);

    test('12 s ticks behave exactly as before (3..300 m)', () {
      expect(steps(2.9, 12), 0);
      expect(steps(3, 12), 3);
      expect(steps(17, 12), 17);
      expect(steps(300, 12), 300);
      expect(steps(301, 12), 0);
    });

    test('a three-minute gap counts a walk but not a drive', () {
      expect(steps(250, 180, acc: 20, last: 20), 250);
      expect(steps(540, 180, acc: 20, last: 20), 540);
      expect(steps(2500, 180, acc: 20, last: 20), 0);
    });

    test('a ten-minute gap allows walking speed, not teleports', () {
      expect(steps(1700, 600, acc: 20, last: 20), 1700);
      expect(steps(2500, 600, acc: 20, last: 20), 0);
    });

    test('coarse wander of a stationary phone is not counted', () {
      expect(steps(120, 180, acc: 80, last: 90), 0);
      expect(steps(400, 180, acc: 80, last: 90), 400);
    });
  });
}
