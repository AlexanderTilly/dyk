import 'dart:async';

import 'package:geofencing_api/geofencing_api.dart';

import '../models/hotspot.dart';

class GeoFencingService {
  final _enterController = StreamController<Hotspot>.broadcast();
  final Set<String> _triggeredIds = {};
  List<Hotspot> _hotspots = [];

  Stream<Hotspot> get onHotspotEnter => _enterController.stream;
  Set<String> get triggeredIds => Set.unmodifiable(_triggeredIds);

  void markTriggered(String id) => _triggeredIds.add(id);
  bool hasBeenTriggered(String id) => _triggeredIds.contains(id);
  void resetSession() => _triggeredIds.clear();

  void emitEnter(Hotspot hotspot) {
    if (!_enterController.isClosed && !hasBeenTriggered(hotspot.id)) {
      markTriggered(hotspot.id);
      _enterController.add(hotspot);
    }
  }

  Future<void> startMonitoring(List<Hotspot> hotspots) async {
    _hotspots = hotspots;

    // Build circular geofence regions from hotspots
    final regions = hotspots
        .map(
          (h) => GeofenceRegion.circular(
            id: h.id,
            center: LatLng(h.lat, h.lng),
            radius: h.radiusMeters.toDouble(),
          ),
        )
        .toSet();

    // Register enter listener
    Geofencing.instance.addGeofenceStatusChangedListener(
      _onGeofenceStatusChanged,
    );

    // Start the geofencing service
    await Geofencing.instance.start(regions: regions);
  }

  Future<void> _onGeofenceStatusChanged(
    GeofenceRegion region,
    GeofenceStatus status,
    Location location,
  ) async {
    if (status == GeofenceStatus.enter) {
      final hotspot = _hotspots.where((h) => h.id == region.id).firstOrNull;
      if (hotspot != null) {
        emitEnter(hotspot);
      }
    }
  }

  Future<void> stop() async {
    Geofencing.instance.removeGeofenceStatusChangedListener(
      _onGeofenceStatusChanged,
    );
    await Geofencing.instance.stop();
  }

  Future<void> dispose() async {
    await stop();
    await _enterController.close();
  }
}
