import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../models/hotspot.dart';
import '../services/audio_service.dart';
import 'hotspot_detail_screen.dart';
import 'list_screen.dart';

class MapScreen extends StatefulWidget {
  final List<Hotspot> hotspots;
  final AudioService audioService;

  const MapScreen({
    super.key,
    required this.hotspots,
    required this.audioService,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapboxMap? _mapboxMap;

  static const _palmaCenterLng = 2.6500;
  static const _palmaCenterLat = 39.5690;

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    await _addHotspotAnnotations();
  }

  Future<void> _addHotspotAnnotations() async {
    if (_mapboxMap == null) return;
    final annotationManager =
        await _mapboxMap!.annotations.createPointAnnotationManager();

    for (final h in widget.hotspots) {
      final options = PointAnnotationOptions(
        geometry: Point(coordinates: Position(h.lng, h.lat)),
        iconSize: 1.5,
        textField: h.name,
        textOffset: [0, 1.8],
        textSize: 12,
        textColor: 0xFF431407,
        iconColor: 0xFFF97316,
      );
      await annotationManager.create(options);
    }

    annotationManager.addOnPointAnnotationClickListener(
      _AnnotationClickListener(widget.hotspots, _openHotspot),
    );
  }

  void _openHotspot(Hotspot hotspot) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HotspotDetailScreen(
          hotspot: hotspot,
          audioService: widget.audioService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      appBar: AppBar(
        title: const Text('Palma Explorer'),
        backgroundColor: const Color(0xFFF97316),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ListScreen(
                    hotspots: widget.hotspots,
                    audioService: widget.audioService,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: MapWidget(
        key: const ValueKey('mapbox_map'),
        cameraOptions: CameraOptions(
          center: Point(
            coordinates: Position(_palmaCenterLng, _palmaCenterLat),
          ),
          zoom: 14.5,
        ),
        styleUri: MapboxStyles.MAPBOX_STREETS,
        onMapCreated: _onMapCreated,
      ),
    );
  }
}

class _AnnotationClickListener extends OnPointAnnotationClickListener {
  final List<Hotspot> hotspots;
  final void Function(Hotspot) onTap;

  _AnnotationClickListener(this.hotspots, this.onTap);

  @override
  void onPointAnnotationClick(PointAnnotation annotation) {
    final coords = annotation.geometry.coordinates;
    final lng = coords.lng;
    final lat = coords.lat;

    final hotspot = hotspots.firstWhere(
      (h) => (h.lng - lng).abs() < 0.0001 && (h.lat - lat).abs() < 0.0001,
      orElse: () => hotspots.first,
    );
    onTap(hotspot);
  }
}
