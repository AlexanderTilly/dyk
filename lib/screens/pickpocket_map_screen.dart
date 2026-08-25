import 'dart:typed_data';

import 'package:flutter/material.dart' hide Visibility;
import '../i18n/i18n.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart' hide Position;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../models/pickpocket_report.dart';
import '../services/dyk_repository.dart';

/// Full-screen map showing only active pickpocket reports. Tapping a pin
/// reveals the reporter's description.
class PickpocketMapScreen extends StatefulWidget {
  final DykRepositoryBase repo;
  const PickpocketMapScreen({super.key, required this.repo});

  @override
  State<PickpocketMapScreen> createState() => _PickpocketMapScreenState();
}

class _PickpocketMapScreenState extends State<PickpocketMapScreen> {
  MapboxMap? _map;
  PointAnnotationManager? _annotations;
  List<PickpocketReport> _reports = [];
  Uint8List? _pinBytes;

  static const _palmaCenterLng = 2.6500;
  static const _palmaCenterLat = 39.5690;

  void _onMapCreated(MapboxMap map) async {
    _map = map;
    await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    final puckBytes = await rootBundle.load('assets/images/location_puck.png');
    await map.location.updateSettings(LocationComponentSettings(
      enabled: true,
      pulsingEnabled: true,
      pulsingColor: 0xFF1559D6,
      locationPuck: LocationPuck(
        locationPuck2D: DefaultLocationPuck2D(
          topImage: puckBytes.buffer.asUint8List(),
        ),
      ),
    ));
    _annotations = await map.annotations.createPointAnnotationManager();
    await _load();
  }

  Future<void> _load() async {
    final manager = _annotations;
    if (manager == null) return;
    _pinBytes ??= (await rootBundle
            .load('assets/images/badges/pickpocket_mappin.png'))
        .buffer
        .asUint8List();
    final reports = await widget.repo.loadPickpocketReports();
    if (!mounted) return;
    setState(() => _reports = reports);

    await manager.deleteAll();
    for (final r in reports) {
      await manager.create(PointAnnotationOptions(
        geometry: Point(coordinates: Position(r.lng, r.lat)),
        image: _pinBytes,
        iconSize: 0.18,
        iconAnchor: IconAnchor.BOTTOM,
      ));
    }
    manager.addOnPointAnnotationClickListener(
      _PinClick((coords) {
        final r = _reports
            .where((x) =>
                (x.lng - coords.lng).abs() < 0.0001 &&
                (x.lat - coords.lat).abs() < 0.0001)
            .firstOrNull;
        if (r != null) _showReport(r);
      }),
    );
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    return '${d.inHours} h ago';
  }

  void _showReport(PickpocketReport r) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset('assets/images/badges/pickpocket.png',
                    height: 40, width: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(tr('pickpocket_activity'),
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0E1726))),
                ),
                Text(_ago(r.createdAt),
                    style:
                        const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              r.description?.isNotEmpty == true
                  ? r.description!
                  : 'No description provided.',
              style: TextStyle(
                  fontSize: 15, height: 1.4, color: Color(0xFF26313F)),
            ),
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF4FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule, size: 16, color: Color(0xFF1559D6)),
                  SizedBox(width: 6),
                  Text(tr('pickpocket_temp'),
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFF1559D6))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _centerOnUser() async {
    final map = _map;
    if (map == null) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      await map.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(pos.longitude, pos.latitude)),
          zoom: 15.5,
        ),
        MapAnimationOptions(duration: 900),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('pickpocket_activity'),
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: const Color(0xFF1559D6),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MapWidget(
            key: const ValueKey('pickpocket_map'),
            cameraOptions: CameraOptions(
              center: Point(
                coordinates: Position(_palmaCenterLng, _palmaCenterLat),
              ),
              zoom: 14.0,
            ),
            styleUri: MapboxStyles.DARK,
            onMapCreated: _onMapCreated,
          ),
          if (_reports.isEmpty)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10),
                  ],
                ),
                child: const Text(
                  'No active pickpocket reports right now. Stay alert and report anything you see.',
                  style: TextStyle(color: Color(0xFF26313F)),
                ),
              ),
            ),
          Positioned(
            right: 16,
            bottom: 24,
            child: FloatingActionButton(
              heroTag: 'pickpocketFindMe',
              backgroundColor: const Color(0xFF1559D6),
              foregroundColor: Colors.white,
              onPressed: _centerOnUser,
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinClick extends OnPointAnnotationClickListener {
  final void Function(Position coords) onClick;
  _PinClick(this.onClick);

  @override
  void onPointAnnotationClick(PointAnnotation annotation) {
    onClick(annotation.geometry.coordinates);
  }
}
