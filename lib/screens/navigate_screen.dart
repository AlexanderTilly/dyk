import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart' hide Visibility;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../i18n/i18n.dart';
import '../models/hotspot.dart';
import '../theme/dyk_theme.dart';
import '../widgets/dyk_puck.dart';
import '../widgets/photo_pin.dart';

const _mapboxToken =
    'pk.eyJ1IjoibGl0dGxld2h5IiwiYSI6ImNtZHJnMjc2bzBoM2EybHNmMWtpNW4xd24ifQ.NMHAZQhN_eP_3wxFUfNhdw';

/// In-app walking navigation to a single hotspot — the fastest footpath,
/// turn-by-turn, no need to jump out to Google Maps.
class NavigateScreen extends StatefulWidget {
  final Hotspot hotspot;
  const NavigateScreen({super.key, required this.hotspot});

  @override
  State<NavigateScreen> createState() => _NavigateScreenState();
}

class _NavigateScreenState extends State<NavigateScreen> {
  MapboxMap? _map;
  StreamSubscription<geo.Position>? _posSub;
  geo.Position? _lastPos;
  List<Map<String, dynamic>> _steps = [];
  double _stepDistance = 0;
  int _currentStep = 0;
  double _remaining = 0;
  bool _arrived = false;
  geo.Position? _routedFrom;
  // walking | cycling | driving — auto-picked on first fix, user-switchable.
  String _mode = 'walking';
  bool _modeAutoPicked = false;

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  void _onMapCreated(MapboxMap map) async {
    _map = map;
    await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await map.location.updateSettings(LocationComponentSettings(
      enabled: true,
      pulsingEnabled: false,
      puckBearingEnabled: true,
      locationPuck: LocationPuck(
        locationPuck2D: DefaultLocationPuck2D(topImage: await buildDykPuck()),
      ),
    ));
    // Destination pin: the hotspot's own photo (badge-less fallback dot).
    try {
      final mgr = await map.annotations.createPointAnnotationManager();
      final h = widget.hotspot;
      final photo =
          h.images.isNotEmpty ? await buildPhotoPin(h.images.first) : null;
      await mgr.create(PointAnnotationOptions(
        geometry: Point(coordinates: Position(h.lng, h.lat)),
        image: photo,
        iconSize: photo != null ? 0.38 : 1.0,
        iconAnchor: IconAnchor.BOTTOM,
        textField: h.name,
        textAnchor: TextAnchor.TOP,
        textOffset: [0, 0.6],
        textSize: 12,
        textColor: 0xFFFFFFFF,
        textHaloColor: 0xFF000000,
        textHaloWidth: 1.5,
      ));
    } catch (_) {}

    // Route layers (empty until the first fix routes us).
    try {
      await map.style.addSource(GeoJsonSource(
          id: 'nav-route',
          data: '{"type":"FeatureCollection","features":[]}'));
      await map.style.addLayer(LineLayer(
        id: 'nav-glow',
        sourceId: 'nav-route',
        lineColor: 0xFFFFC107,
        lineWidth: 16.0,
        lineOpacity: 0.15,
        lineBlur: 4.0,
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
      ));
      await map.style.addLayer(LineLayer(
        id: 'nav-casing',
        sourceId: 'nav-route',
        lineColor: 0xFF1A1A1A,
        lineWidth: 9.0,
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
      ));
      await map.style.addLayer(LineLayer(
        id: 'nav-line',
        sourceId: 'nav-route',
        lineColor: 0xFFFFC107,
        lineWidth: 6.0,
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
      ));
    } catch (_) {}

    geo.Geolocator.getCurrentPosition(
            desiredAccuracy: geo.LocationAccuracy.high)
        .then((p) {
      if (mounted) _onPosition(p);
    }).catchError((_) {});
    _posSub = geo.Geolocator.getPositionStream(
      locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high, distanceFilter: 6),
    ).listen(_onPosition);
  }

  Future<void> _fetchRoute(geo.Position pos) async {
    _routedFrom = pos;
    final h = widget.hotspot;
    try {
      final url = Uri.parse(
          'https://api.mapbox.com/directions/v5/mapbox/$_mode/'
          '${pos.longitude},${pos.latitude};${h.lng},${h.lat}'
          '?geometries=geojson&overview=full&steps=true&access_token=$_mapboxToken');
      final res = await http.get(url).timeout(const Duration(seconds: 10));
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final route = (json['routes'] as List?)?.firstOrNull;
      if (route == null || !mounted) return;
      final coords = route['geometry']?['coordinates'];
      if (coords is List) {
        final data = jsonEncode({
          'type': 'Feature',
          'geometry': {'type': 'LineString', 'coordinates': coords},
          'properties': {},
        });
        try {
          await _map?.style.setStyleSourceProperty('nav-route', 'data', data);
        } catch (_) {}
      }
      setState(() {
        _remaining = (route['distance'] as num?)?.toDouble() ?? 0;
        _steps = [
          for (final leg in (route['legs'] as List? ?? []))
            for (final st in (leg['steps'] as List? ?? []))
              {
                'instruction': st['maneuver']?['instruction'],
                'type': st['maneuver']?['type'],
                'modifier': st['maneuver']?['modifier'],
                'location': st['maneuver']?['location'],
              },
        ];
        _currentStep = 0;
      });
    } catch (_) {}
  }

  void _onPosition(geo.Position pos) {
    _lastPos = pos;
    final h = widget.hotspot;
    final toTarget = geo.Geolocator.distanceBetween(
        pos.latitude, pos.longitude, h.lat, h.lng);

    // First fix: walking inside ~2.5 km, driving beyond — then it's yours.
    if (!_modeAutoPicked) {
      _modeAutoPicked = true;
      if (toTarget > 2500) _mode = 'driving';
    }

    if (!_arrived && toTarget <= h.radiusMeters.toDouble().clamp(30, 100)) {
      setState(() => _arrived = true);
    }

    // (Re)route on first fix or after drifting off the fetched route.
    final from = _routedFrom;
    if (from == null ||
        geo.Geolocator.distanceBetween(pos.latitude, pos.longitude,
                from.latitude, from.longitude) >
            120) {
      _fetchRoute(pos);
    }

    // Advance the turn-by-turn step.
    if (_steps.isNotEmpty) {
      var idx = _currentStep;
      while (idx < _steps.length - 1) {
        final loc = _steps[idx]['location'] as List?;
        if (loc == null || loc.length < 2) break;
        final d = geo.Geolocator.distanceBetween(pos.latitude, pos.longitude,
            (loc[1] as num).toDouble(), (loc[0] as num).toDouble());
        if (d < 18) {
          idx++;
        } else {
          break;
        }
      }
      final loc = _steps[idx]['location'] as List?;
      final dist = loc != null && loc.length >= 2
          ? geo.Geolocator.distanceBetween(pos.latitude, pos.longitude,
              (loc[1] as num).toDouble(), (loc[0] as num).toDouble())
          : 0.0;
      setState(() {
        _currentStep = idx;
        _stepDistance = dist;
        _remaining = toTarget < _remaining ? toTarget : _remaining;
      });
    } else {
      setState(() => _remaining = toTarget);
    }

    _map?.easeTo(
      CameraOptions(
        center: Point(coordinates: Position(pos.longitude, pos.latitude)),
        zoom: 16.5,
        pitch: 45,
        bearing: pos.heading >= 0 ? pos.heading : null,
      ),
      MapAnimationOptions(duration: 900),
    );
  }

  IconData _maneuverIcon(Map<String, dynamic> step) {
    final type = step['type'] as String? ?? '';
    final mod = step['modifier'] as String? ?? '';
    if (type == 'arrive') return Icons.sports_score;
    if (type == 'depart') return Icons.navigation;
    if (mod.contains('uturn')) return Icons.u_turn_left;
    if (mod.contains('sharp right')) return Icons.turn_sharp_right;
    if (mod.contains('sharp left')) return Icons.turn_sharp_left;
    if (mod.contains('slight right')) return Icons.turn_slight_right;
    if (mod.contains('slight left')) return Icons.turn_slight_left;
    if (mod.contains('right')) return Icons.turn_right;
    if (mod.contains('left')) return Icons.turn_left;
    return Icons.straight;
  }

  String _fmt(double m) =>
      m >= 1000 ? '${(m / 1000).toStringAsFixed(1)} km' : '${m.round()} m';

  void _setMode(String mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _steps = [];
      _currentStep = 0;
    });
    final pos = _lastPos;
    if (pos != null) _fetchRoute(pos);
  }

  Widget _modeChip(String mode, IconData icon) {
    final selected = _mode == mode;
    return GestureDetector(
      onTap: () => _setMode(mode),
      child: Container(
        width: 42,
        height: 42,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: selected ? DykColors.yellow : const Color(0xFF1A1A1A),
          shape: BoxShape.circle,
          border: Border.all(
              color: selected ? DykColors.yellow : Colors.white24,
              width: 1.5),
        ),
        child: Icon(icon,
            size: 22,
            color: selected ? DykColors.black : Colors.white70),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.hotspot;
    return Scaffold(
      appBar: AppBar(
        title: Text(h.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MapWidget(
            key: const ValueKey('navigate_map'),
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(h.lng, h.lat)),
              zoom: 15,
            ),
            styleUri: MapboxStyles.DARK,
            onMapCreated: _onMapCreated,
          ),
          if (_steps.isNotEmpty && !_arrived)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: DykColors.yellow, width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                          color: DykColors.yellow, shape: BoxShape.circle),
                      child: Icon(_maneuverIcon(_steps[_currentStep]),
                          color: DykColors.black, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_fmt(_stepDistance),
                              style: const TextStyle(
                                  color: DykColors.yellow,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17)),
                          Text(
                            (_steps[_currentStep]['instruction'] as String?) ??
                                '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_arrived)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: DykColors.yellow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.celebration, color: DykColors.black),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('${tr('youve_arrived')} 🎉',
                          style: const TextStyle(
                              color: DykColors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 16)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(tr('done'),
                          style: const TextStyle(
                              color: DykColors.black,
                              fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              ),
            ),
          // Transport mode switcher (auto-picked; tap to change).
          Positioned(
            right: 12,
            top: 96,
            child: Column(
              children: [
                _modeChip('walking', Icons.directions_walk),
                _modeChip('cycling', Icons.directions_bike),
                _modeChip('driving', Icons.directions_car),
              ],
            ),
          ),

          // Remaining-distance card.
          Positioned(
            left: 16,
            right: 16,
            bottom: 16 + MediaQuery.of(context).padding.bottom,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: DykColors.yellow, width: 1.5),
              ),
              child: Row(
                children: [
                  _mode == 'walking'
                      ? const FootstepsIcon(size: 20)
                      : Icon(transportIcon(_mode),
                          color: DykColors.yellow, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${_fmt(_remaining)} ${tr('to_go')}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15),
                    ),
                  ),
                  if (_mode == 'driving')
                    Text(tr('parking_note'),
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 10)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
