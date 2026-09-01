import '../models/hot_deal.dart';
import '../models/hotspot.dart';
import 'geo_zones.dart' show distanceMeters;

/// Something the user just reached and should be told about.
class ProximityHit {
  final String kind; // 'hotspot' | 'deal'
  final String id;
  const ProximityHit(this.kind, this.id);

  @override
  bool operator ==(Object other) =>
      other is ProximityHit && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);

  @override
  String toString() => '$kind:$id';
}

/// Decides what to notify about, given a position.
///
/// Deliberately free of plugins, prefs and I/O so the rules can be tested
/// without a device: the caller supplies the state and performs the effects.
/// The Android background isolate keeps its own copy of this logic for now;
/// this one drives iOS, where the checks run in the app's own isolate.
class ProximityEngine {
  /// Ids already notified about, until the user leaves the area again.
  final Set<String> _triggered = {};

  /// Metres beyond the radius the user must travel before a place can fire
  /// again — otherwise standing on the edge would notify repeatedly.
  final double rearmBuffer;

  ProximityEngine({this.rearmBuffer = 30});

  Set<String> get triggered => Set.unmodifiable(_triggered);
  void reset() => _triggered.clear();

  List<ProximityHit> check({
    required double lat,
    required double lng,
    required List<Hotspot> hotspots,
    required List<HotDeal> deals,
    required Set<String> interests,
    required bool tourActive,
    required int stepsToday,
    DateTime? now,
    DateTime? cityArrivedAt,
  }) {
    final hits = <ProximityHit>[];
    final at = now ?? DateTime.now();

    // While a tour is running it owns the experience — stray pings would talk
    // over the guide. The tour screen fires its own arrivals.
    if (!tourActive) {
      for (final h in hotspots) {
        if (!interests.contains(h.category)) continue;
        if (_reached('h_${h.id}', lat, lng, h.lat, h.lng,
            h.radiusMeters.toDouble())) {
          hits.add(ProximityHit('hotspot', h.id));
        }
      }
    }

    if (interests.contains('hotdeal')) {
      for (final d in deals) {
        if (!dealTargets(d,
            stepsToday: stepsToday,
            tourActive: tourActive,
            interests: interests,
            cityArrivedAt: cityArrivedAt,
            now: at)) {
          continue;
        }
        if (_reached('d_${d.id}', lat, lng, d.lat, d.lng,
            d.radiusMeters.toDouble())) {
          hits.add(ProximityHit('deal', d.id));
        }
      }
    }

    return hits;
  }

  bool _reached(String key, double lat, double lng, double targetLat,
      double targetLng, double radius) {
    final d = distanceMeters(lat, lng, targetLat, targetLng);
    if (_triggered.contains(key)) {
      if (d > radius + rearmBuffer) _triggered.remove(key);
      return false;
    }
    if (d > radius) return false;
    _triggered.add(key);
    return true;
  }

  /// Does this deal's targeting match the user right now?
  ///
  /// Merchants pick segments; the matching happens here, on the device, so no
  /// personal data ever reaches them.
  static bool dealTargets(
    HotDeal d, {
    required int stepsToday,
    required bool tourActive,
    required Set<String> interests,
    DateTime? cityArrivedAt,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();

    if (stepsToday < d.minStepsToday) return false;

    if (d.targetOnTour == 'exclude' && tourActive) return false;
    if (d.targetOnTour == 'only' && !tourActive) return false;

    if (d.activeDays.isNotEmpty) {
      // Dart: Monday = 1 … Sunday = 7. Admin/Postgres: Sunday = 0.
      final dow = at.weekday == 7 ? 0 : at.weekday;
      if (!d.activeDays.contains(dow)) return false;
    }

    if (at.hour < d.activeHourFrom || at.hour >= d.activeHourTo) return false;

    if (d.targetArrival == 'new') {
      if (cityArrivedAt == null) return false;
      if (at.difference(cityArrivedAt).inHours > 24) return false;
    }

    final want = d.targetInterest;
    if (want != null && want.isNotEmpty && !interests.contains(want)) {
      return false;
    }

    return true;
  }
}
