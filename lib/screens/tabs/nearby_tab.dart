import 'package:flutter/material.dart' hide Visibility;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../models/hotspot.dart';
import '../../services/audio_service.dart';
import '../../theme/dyk_theme.dart';
import '../hotspot_detail_screen.dart';

const _categoryMeta = {
  'history': ('🏛️', 'History'),
  'funfact': ('💡', 'Fun Facts'),
  'headline': ('📰', 'Headlines'),
};

class NearbyTab extends StatefulWidget {
  final List<Hotspot> hotspots;
  final AudioService audioService;

  const NearbyTab({
    super.key,
    required this.hotspots,
    required this.audioService,
  });

  @override
  State<NearbyTab> createState() => _NearbyTabState();
}

class _NearbyTabState extends State<NearbyTab> {
  MapboxMap? _map;
  PointAnnotationManager? _annotations;
  final Set<String> _visibleCategories = {'history', 'funfact', 'headline'};
  String _search = '';

  static const _palmaCenterLng = 2.6500;
  static const _palmaCenterLat = 39.5690;

  List<Hotspot> get _filtered => widget.hotspots
      .where((h) =>
          _visibleCategories.contains(h.category) &&
          (_search.isEmpty ||
              h.name.toLowerCase().contains(_search.toLowerCase())))
      .toList();

  void _onMapCreated(MapboxMap map) async {
    _map = map;
    _annotations = await map.annotations.createPointAnnotationManager();
    await _refreshPins();
  }

  Future<void> _refreshPins() async {
    final manager = _annotations;
    if (manager == null) return;
    await manager.deleteAll();

    for (final h in _filtered) {
      await manager.create(PointAnnotationOptions(
        geometry: Point(coordinates: Position(h.lng, h.lat)),
        iconSize: 1.5,
        textField: '${_categoryMeta[h.category]?.$1 ?? '📍'} ${h.name}',
        textOffset: [0, 1.8],
        textSize: 12,
        textColor: 0xFF1A1A1A,
        iconColor: 0xFFFFC107,
      ));
    }

    manager.addOnPointAnnotationClickListener(
      _PinClickListener(_filtered, _openHotspot),
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

  void _toggleCategory(String c) {
    setState(() {
      _visibleCategories.contains(c)
          ? _visibleCategories.remove(c)
          : _visibleCategories.add(c);
    });
    _refreshPins();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search places, landmarks, deals...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: dark ? Colors.white10 : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (v) {
              setState(() => _search = v);
              _refreshPins();
            },
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final entry in _categoryMeta.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    selected: _visibleCategories.contains(entry.key),
                    selectedColor: DykColors.yellow,
                    checkmarkColor: DykColors.black,
                    label: Text('${entry.value.$1} ${entry.value.$2}'),
                    onSelected: (_) => _toggleCategory(entry.key),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: MapWidget(
            key: const ValueKey('nearby_map'),
            cameraOptions: CameraOptions(
              center: Point(
                coordinates: Position(_palmaCenterLng, _palmaCenterLat),
              ),
              zoom: 14.5,
            ),
            styleUri: dark ? MapboxStyles.DARK : MapboxStyles.MAPBOX_STREETS,
            onMapCreated: _onMapCreated,
          ),
        ),
      ],
    );
  }
}

class _PinClickListener extends OnPointAnnotationClickListener {
  final List<Hotspot> hotspots;
  final void Function(Hotspot) onTap;

  _PinClickListener(this.hotspots, this.onTap);

  @override
  void onPointAnnotationClick(PointAnnotation annotation) {
    final coords = annotation.geometry.coordinates;
    final hotspot = hotspots
        .where((h) =>
            (h.lng - coords.lng).abs() < 0.0001 &&
            (h.lat - coords.lat).abs() < 0.0001)
        .firstOrNull;
    if (hotspot != null) onTap(hotspot);
  }
}
