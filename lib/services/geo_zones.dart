import 'dart:math' as math;

import '../models/hotspot.dart';

/// A coarse area that contains one or more hotspots.
///
/// iOS wakes an app reliably when it crosses a region boundary, but region
/// monitoring is unreliable below roughly 150 m — and most hotspots use a
/// 20 m radius. So we monitor a handful of wide zones instead, and switch on
/// precise location only while the user is inside one.
class GeoZone {
  final String id;
  final double lat;
  final double lng;
  final double radiusMeters;
  final int hotspotCount;

  const GeoZone({
    required this.id,
    required this.lat,
    required this.lng,
    required this.radiusMeters,
    required this.hotspotCount,
  });

  @override
  String toString() =>
      'GeoZone($id, ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}, '
      '${radiusMeters.round()} m, $hotspotCount hotspots)';
}

/// Metres between two coordinates (haversine).
double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const earthRadius = 6371000.0;
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _rad(double deg) => deg * math.pi / 180;

/// Group hotspots into a few wide zones.
///
/// Greedy clustering: walk the hotspots, and add each one to the first zone
/// whose centre is within [clusterRadius]; otherwise start a new zone. The
/// input is sorted by id first, so the zones come out identical on every
/// launch no matter what order the database returned rows in — otherwise iOS
/// would keep re-registering regions for no reason.
///
/// [minRadius] guards against zones so small that iOS cannot detect the
/// crossing; [padding] adds a margin so the precise layer is already running
/// by the time the user reaches the first hotspot.
List<GeoZone> buildZones(
  List<Hotspot> hotspots, {
  double clusterRadius = 1200,
  double minRadius = 250,
  double padding = 150,
}) {
  final clusters = <List<Hotspot>>[];
  final centres = <List<double>>[]; // [lat, lng] running mean per cluster

  final ordered = [...hotspots]..sort((a, b) => a.id.compareTo(b.id));
  for (final h in ordered) {
    // Coordinates that were never set would drag a zone into the Atlantic.
    if (h.lat == 0 && h.lng == 0) continue;

    var joined = false;
    for (var i = 0; i < clusters.length; i++) {
      final d = distanceMeters(centres[i][0], centres[i][1], h.lat, h.lng);
      if (d <= clusterRadius) {
        clusters[i].add(h);
        final n = clusters[i].length;
        centres[i][0] += (h.lat - centres[i][0]) / n;
        centres[i][1] += (h.lng - centres[i][1]) / n;
        joined = true;
        break;
      }
    }
    if (!joined) {
      clusters.add([h]);
      centres.add([h.lat, h.lng]);
    }
  }

  final zones = <GeoZone>[];
  for (var i = 0; i < clusters.length; i++) {
    final lat = centres[i][0];
    final lng = centres[i][1];
    var furthest = 0.0;
    for (final h in clusters[i]) {
      final d = distanceMeters(lat, lng, h.lat, h.lng);
      if (d > furthest) furthest = d;
    }
    zones.add(GeoZone(
      id: 'zone_$i',
      lat: lat,
      lng: lng,
      radiusMeters: math.max(minRadius, furthest + padding),
      hotspotCount: clusters[i].length,
    ));
  }
  return zones;
}

/// iOS monitors at most 20 regions per app, and other features need a couple
/// of slots, so keep the nearest [limit] zones to the user.
List<GeoZone> nearestZones(
  List<GeoZone> zones,
  double lat,
  double lng, {
  int limit = 18,
}) {
  final sorted = [...zones]..sort((a, b) => distanceMeters(lat, lng, a.lat, a.lng)
      .compareTo(distanceMeters(lat, lng, b.lat, b.lng)));
  return sorted.take(limit).toList();
}
