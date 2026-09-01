import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geofencing_api/geofencing_api.dart';
import 'package:geolocator/geolocator.dart' as geo;

import '../models/hotspot.dart';
import 'geo_zones.dart';

/// The iOS half of the background engine.
///
/// Android keeps a foreground service ticking every 12 s. iOS has no such
/// thing, so this class uses the one wake-up iOS is reliable at — crossing a
/// region boundary — and switches on precise location only while the user is
/// actually among hotspots:
///
///   coarse layer   a handful of wide zones (see [buildZones]); iOS wakes the
///                  app on entry even when it has been terminated
///   precise layer  a continuous location stream, started on entry and stopped
///                  on exit, that does the real 20 m proximity checks
///
/// Keeping the precise layer off outside the zones is what makes this
/// acceptable on battery — and what Apple expects to see in review.
class IosGeoService {
  IosGeoService({
    required this.onPosition,
    this.precisionDistanceFilter = 10,
  });

  /// Called for every precise fix. The caller owns proximity logic and
  /// notifications, so this class stays about location only.
  final void Function(geo.Position position) onPosition;

  /// Metres the user must move before another fix is delivered.
  final int precisionDistanceFilter;

  final Set<String> _insideZones = {};
  StreamSubscription<geo.Position>? _preciseSub;
  List<GeoZone> _zones = const [];
  bool _running = false;

  bool get isRunning => _running;
  bool get isPrecise => _preciseSub != null;
  List<GeoZone> get zones => List.unmodifiable(_zones);
  Set<String> get insideZones => Set.unmodifiable(_insideZones);

  /// Build zones from [hotspots] and start monitoring the ones nearest the
  /// user. Safe to call again when content changes; it re-registers cleanly.
  Future<void> start(List<Hotspot> hotspots) async {
    await stop();

    final all = buildZones(hotspots);
    if (all.isEmpty) return;

    // Keep the closest zones — iOS monitors at most 20 regions per app.
    geo.Position? here;
    try {
      here = await geo.Geolocator.getCurrentPosition(
          desiredAccuracy: geo.LocationAccuracy.medium);
    } catch (_) {
      // No fix yet: monitor the first zones rather than none at all.
    }
    _zones = here == null
        ? all.take(18).toList()
        : nearestZones(all, here.latitude, here.longitude);

    Geofencing.instance.addGeofenceStatusChangedListener(_onStatusChanged);
    await Geofencing.instance.start(
      regions: _zones
          .map((z) => GeofenceRegion.circular(
                id: z.id,
                center: LatLng(z.lat, z.lng),
                radius: z.radiusMeters,
              ))
          .toSet(),
    );
    _running = true;

    // Entering a zone is an event — being inside one already is not. Without
    // this check, opening the app in the middle of the old town would leave
    // the precise layer off until the user walked out and back in.
    if (here != null) _syncFromPosition(here);
  }

  Future<void> stop() async {
    Geofencing.instance.removeGeofenceStatusChangedListener(_onStatusChanged);
    if (_running) await Geofencing.instance.stop();
    await _stopPrecise();
    _insideZones.clear();
    _running = false;
  }

  Future<void> _onStatusChanged(
    GeofenceRegion region,
    GeofenceStatus status,
    Location location,
  ) async {
    if (status == GeofenceStatus.enter) {
      _insideZones.add(region.id);
      await _startPrecise();
    } else if (status == GeofenceStatus.exit) {
      _insideZones.remove(region.id);
      if (_insideZones.isEmpty) await _stopPrecise();
    }
  }

  /// Decide the mode from a known position (used at startup).
  void _syncFromPosition(geo.Position pos) {
    for (final z in _zones) {
      final inside =
          distanceMeters(z.lat, z.lng, pos.latitude, pos.longitude) <=
              z.radiusMeters;
      if (inside) {
        _insideZones.add(z.id);
      } else {
        _insideZones.remove(z.id);
      }
    }
    if (_insideZones.isEmpty) {
      _stopPrecise();
    } else {
      _startPrecise();
      onPosition(pos);
    }
  }

  Future<void> _startPrecise() async {
    if (_preciseSub != null) return;
    debugPrint('IosGeoService: precise layer ON (${_insideZones.length} zones)');
    _preciseSub = geo.Geolocator.getPositionStream(
      locationSettings: geo.AppleSettings(
        accuracy: geo.LocationAccuracy.best,
        distanceFilter: precisionDistanceFilter,
        // Keeps delivering fixes with the screen off — the whole point.
        allowBackgroundLocationUpdates: true,
        // iOS would otherwise pause updates when it thinks the user stopped,
        // and never resume on its own.
        pauseLocationUpdatesAutomatically: false,
        // No blue banner: the user opted in, and a walking guide showing it
        // constantly reads as a tracking app.
        showBackgroundLocationIndicator: false,
        activityType: geo.ActivityType.fitness,
      ),
    ).listen(onPosition, onError: (Object e) {
      debugPrint('IosGeoService: precise stream error: $e');
    });
  }

  Future<void> _stopPrecise() async {
    if (_preciseSub == null) return;
    debugPrint('IosGeoService: precise layer OFF');
    await _preciseSub!.cancel();
    _preciseSub = null;
  }
}
