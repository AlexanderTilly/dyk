import 'package:flutter_test/flutter_test.dart';
import 'package:palma_app/models/hotspot.dart';
import 'package:palma_app/services/geo_zones.dart';

Hotspot _h(String id, double lat, double lng) => Hotspot(
      id: id,
      name: id,
      subtitle: '',
      description: '',
      lat: lat,
      lng: lng,
      radiusMeters: 20,
      audioFile: '',
      images: const [],
      year: '',
    );

void main() {
  group('distanceMeters', () {
    test('is zero for the same point', () {
      expect(distanceMeters(39.5696, 2.6502, 39.5696, 2.6502), closeTo(0, 0.1));
    });

    test('matches a known distance', () {
      // Palma cathedral to Plaça Major, roughly 600 m apart.
      final d = distanceMeters(39.5674, 2.6486, 39.5713, 2.6513);
      expect(d, greaterThan(400));
      expect(d, lessThan(700));
    });
  });

  group('buildZones', () {
    test('groups nearby hotspots into a single zone', () {
      final zones = buildZones([
        _h('a', 39.5674, 2.6486),
        _h('b', 39.5680, 2.6490),
        _h('c', 39.5670, 2.6480),
      ]);
      expect(zones, hasLength(1));
      expect(zones.first.hotspotCount, 3);
    });

    test('splits hotspots that are far apart', () {
      final zones = buildZones([
        _h('palma', 39.5674, 2.6486),
        _h('madrid', 40.4168, -3.7038),
      ]);
      expect(zones, hasLength(2));
    });

    test('never returns a radius iOS cannot detect', () {
      final zones = buildZones([_h('lonely', 39.5674, 2.6486)]);
      expect(zones.single.radiusMeters, greaterThanOrEqualTo(250));
    });

    test('covers every hotspot in its zone', () {
      final spots = [
        _h('a', 39.5674, 2.6486),
        _h('b', 39.5700, 2.6520),
        _h('c', 39.5660, 2.6460),
      ];
      final zones = buildZones(spots);
      for (final s in spots) {
        final inside = zones.any((z) =>
            distanceMeters(z.lat, z.lng, s.lat, s.lng) <= z.radiusMeters);
        expect(inside, isTrue, reason: '${s.id} fell outside every zone');
      }
    });

    test('ignores hotspots left at 0,0', () {
      final zones = buildZones([
        _h('real', 39.5674, 2.6486),
        _h('broken', 0, 0),
      ]);
      expect(zones, hasLength(1));
      expect(zones.single.hotspotCount, 1);
    });

    test('is deterministic regardless of input order', () {
      final spots = [
        _h('a', 39.5674, 2.6486),
        _h('b', 39.5700, 2.6520),
        _h('c', 40.4168, -3.7038),
      ];
      final forward = buildZones(spots).map((z) => z.toString()).toList();
      final reversed =
          buildZones(spots.reversed.toList()).map((z) => z.toString()).toList();
      expect(reversed, forward);
    });
  });

  group('nearestZones', () {
    test('keeps the closest zones within the iOS region budget', () {
      final zones = [
        for (var i = 0; i < 30; i++)
          GeoZone(
            id: 'z$i',
            lat: 39.5 + i * 0.05,
            lng: 2.6,
            radiusMeters: 300,
            hotspotCount: 1,
          ),
      ];
      final near = nearestZones(zones, 39.5, 2.6, limit: 18);
      expect(near, hasLength(18));
      expect(near.first.id, 'z0');
    });
  });
}
