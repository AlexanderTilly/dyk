import 'dart:async';

import 'package:geofencing_api/geofencing_api.dart';

import '../models/hot_deal.dart';
import '../models/hotspot.dart';

class GeoFencingService {
  final _enterController = StreamController<Hotspot>.broadcast();
  final _dealController = StreamController<HotDeal>.broadcast();
  final Set<String> _triggeredIds = {};
  List<Hotspot> _hotspots = [];
  List<HotDeal> _deals = [];
  bool _running = false;

  static const _dealPrefix = 'deal_';

  Stream<Hotspot> get onHotspotEnter => _enterController.stream;
  Stream<HotDeal> get onDealEnter => _dealController.stream;
  bool get isRunning => _running;
  Set<String> get triggeredIds => Set.unmodifiable(_triggeredIds);

  void markTriggered(String id) => _triggeredIds.add(id);
  bool hasBeenTriggered(String id) => _triggeredIds.contains(id);
  void resetSession() => _triggeredIds.clear();

  void emitEnter(Hotspot hotspot) {
    if (!_enterController.isClosed) {
      _enterController.add(hotspot);
    }
  }

  void emitDealEnter(HotDeal deal) {
    if (!_dealController.isClosed) {
      _dealController.add(deal);
    }
  }

  Future<void> startMonitoring(
    List<Hotspot> hotspots, {
    List<HotDeal> deals = const [],
  }) async {
    _hotspots = hotspots;
    _deals = deals;

    final regions = <GeofenceRegion>{
      ...hotspots.map(
        (h) => GeofenceRegion.circular(
          id: h.id,
          center: LatLng(h.lat, h.lng),
          radius: h.radiusMeters.toDouble(),
        ),
      ),
      ...deals.map(
        (d) => GeofenceRegion.circular(
          id: '$_dealPrefix${d.id}',
          center: LatLng(d.lat, d.lng),
          radius: d.radiusMeters.toDouble(),
        ),
      ),
    };

    Geofencing.instance.addGeofenceStatusChangedListener(
      _onGeofenceStatusChanged,
    );

    await Geofencing.instance.start(regions: regions);
    _running = true;
  }

  Future<void> _onGeofenceStatusChanged(
    GeofenceRegion region,
    GeofenceStatus status,
    Location location,
  ) async {
    if (status != GeofenceStatus.enter) return;

    if (region.id.startsWith(_dealPrefix)) {
      final dealId = region.id.substring(_dealPrefix.length);
      final deal = _deals.where((d) => d.id == dealId).firstOrNull;
      if (deal != null) emitDealEnter(deal);
    } else {
      final hotspot = _hotspots.where((h) => h.id == region.id).firstOrNull;
      if (hotspot != null) emitEnter(hotspot);
    }
  }

  Future<void> stop() async {
    Geofencing.instance.removeGeofenceStatusChangedListener(
      _onGeofenceStatusChanged,
    );
    await Geofencing.instance.stop();
    _running = false;
  }

  Future<void> dispose() async {
    await stop();
    await _enterController.close();
    await _dealController.close();
  }
}
