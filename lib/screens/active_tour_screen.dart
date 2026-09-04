import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter/services.dart' show rootBundle, HapticFeedback;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../i18n/i18n.dart';
import '../models/tour.dart';
import '../models/tour_stop.dart';
import '../services/audio_service.dart';
import '../services/dyk_repository.dart';
import '../services/step_store.dart';
import '../theme/dyk_theme.dart';
import 'hotspot_detail_screen.dart';
import 'stop_detail_screen.dart';
import '../models/hotspot.dart';
import '../widgets/photo_pin.dart';
import 'tour_complete_screen.dart';

class ActiveTourScreen extends StatefulWidget {
  final Tour tour;
  final List<TourStop> stops;
  final DykRepositoryBase repo;
  final AudioService audioService;

  const ActiveTourScreen({
    super.key,
    required this.tour,
    required this.stops,
    required this.repo,
    required this.audioService,
  });

  @override
  State<ActiveTourScreen> createState() => _ActiveTourScreenState();
}

class _ActiveTourScreenState extends State<ActiveTourScreen>
    with WidgetsBindingObserver {
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;
  final _notifs = FlutterLocalNotificationsPlugin();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
  }

  MapboxMap? _map;
  PointAnnotationManager? _points;
  Set<String> _visited = {};
  StreamSubscription<geo.Position>? _posSub;
  bool _completing = false;

  // Route geometry, parsed once.
  List<List<double>> _routeCoords = []; // [lng, lat]
  int _progressIdx = 0; // index into _routeCoords the user has passed

  // Turn-by-turn navigation.
  late final List<Map<String, dynamic>> _steps = widget.tour.routeSteps;
  late final List<int> _stepRouteIdx; // each step's index on the route line
  int _currentStep = 0;
  double _stepDistance = 0;
  bool _navMinimized = false;

  // Camera follow (GPS style) vs free/overview.
  bool _follow = true;
  geo.Position? _lastPos;

  // "Head to the start" phase: guides the user to the entry point with a
  // dashed line before loop navigation takes over. null = not yet decided.
  bool? _headingToStart;
  double _startDistance = 0;
  // Entry point: stop 1 for fixed tours, nearest stop for hop-on loops.
  TourStop? _guideTarget;
  // Fixed tours hide the loop until the user reaches the start.
  late bool _revealed = widget.tour.startMode == 'hop_on';
  // After finishing a fixed tour: optional guidance back to the start.
  bool _guidingBack = false;

  // Single source of truth for where we're heading. -1 = follow the loop
  // automatically; >= 0 = the user picked a stop manually (dashed guidance).
  int _targetIdx = -1;
  double _targetDist = 0;
  // Stops struck out mid-tour ("skip the morning coffee").
  Set<String> _skippedLive = {};
  // Dwell state: paused at a stop until the user taps "Let's move on".
  bool _dwelling = false;
  // Pacing: optional finish-by time chosen at tour start.
  DateTime? _deadline;
  Timer? _paceTimer;
  int _lastNudgeAt = -1; // visited-count when we last nudged
  final DateTime _startedAt = DateTime.now();
  // Gold-pulse arrival effect: bump the seq to replay the animation.
  int _pulseSeq = 0;
  // Road-following dashed guide (replaces the old as-the-crow-flies line).
  List<List<double>> _guideRouteCoords = [];
  geo.Position? _guideFetchedAt;
  int _guideFetchSeq = 0;

  @override
  void initState() {
    super.initState();
    _parseRoute();
    _stepRouteIdx = _steps.map((s) {
      final loc = s['location'];
      if (loc is! List || loc.length < 2) return 0;
      return _nearestRouteIndex(
          (loc[0] as num).toDouble(), (loc[1] as num).toDouble());
    }).toList();
    _loadProgress();
    WidgetsBinding.instance.addObserver(this);
    SharedPreferences.getInstance()
        .then((p) => p.setBool('tour_active', true));
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAskDeadline());
    _paceTimer =
        Timer.periodic(const Duration(minutes: 1), (_) => _checkPace());
  }

  // ---------- Manual target / skip logic ----------

  List<TourStop> get _remaining => [
        for (final s in widget.stops)
          if (!_visited.contains(s.id) &&
              !_skippedLive.contains(s.id) &&
              s.lat != null &&
              s.lng != null)
            s
      ];

  /// Manually aim for a stop; -1 returns to automatic loop-following.
  void _setTarget(int idx) {
    setState(() => _targetIdx = idx);
    _manualRoute = [];
    _manualFetchedAt = null; // force a fresh road-route fetch
    _drawStops(); // the target pin must be visible even before reveal
    final pos = _lastPos;
    if (pos != null) _updateManualLine(pos);
    // Frame both the user and the target so the goal is on screen.
    final p = _lastPos;
    final map = _map;
    if (idx >= 0 && p != null && map != null) {
      final t = widget.stops[idx];
      setState(() => _follow = false);
      map
          .cameraForCoordinates(
        [
          Point(coordinates: Position(p.longitude, p.latitude)),
          Point(coordinates: Position(t.lng!, t.lat!)),
        ],
        MbxEdgeInsets(top: 180, left: 70, bottom: 170, right: 70),
        null,
        null,
      )
          .then((cam) {
        cam.pitch = 0;
        cam.bearing = 0;
        map.flyTo(cam, MapAnimationOptions(duration: 800));
      }).catchError((_) {});
    }
  }

  /// Step the manual target forward/backward through unfinished stops.
  void _stepTarget(int dir) {
    final rem = _remaining;
    if (rem.isEmpty) return;
    final current = _targetIdx >= 0
        ? widget.stops[_targetIdx]
        : rem.first;
    var i = rem.indexWhere((s) => s.id == current.id);
    if (i < 0) i = 0;
    final next = rem[(i + dir + rem.length) % rem.length];
    _setTarget(widget.stops.indexWhere((s) => s.id == next.id));
  }

  void _toggleSkipLive(TourStop s) {
    if (_visited.contains(s.id)) return;
    setState(() {
      if (_skippedLive.contains(s.id)) {
        _skippedLive = {..._skippedLive}..remove(s.id);
      } else {
        _skippedLive = {..._skippedLive, s.id};
        if (_targetIdx >= 0 && widget.stops[_targetIdx].id == s.id) {
          _targetIdx = -1;
        }
      }
    });
    _drawStops();
    _maybeComplete();
  }

  // Road route to the manual target (fetched from Mapbox Directions).
  List<List<double>> _manualRoute = [];
  geo.Position? _manualFetchedAt;
  int _manualFetchSeq = 0;

  static const _mapboxToken =
      'pk.eyJ1IjoibGl0dGxld2h5IiwiYSI6ImNtZHJnMjc2bzBoM2EybHNmMWtpNW4xd24ifQ.NMHAZQhN_eP_3wxFUfNhdw';

  /// Fetch the road route (tour's transport mode) from [pos] to the manual
  /// target. Boat tours fall back to a straight line — no water routing.
  Future<void> _fetchManualRoute(geo.Position pos) async {
    if (_targetIdx < 0) return;
    final t = widget.stops[_targetIdx];
    final seq = ++_manualFetchSeq;
    _manualFetchedAt = pos;
    if (widget.tour.transportMode == 'boat') {
      _manualRoute = [
        [pos.longitude, pos.latitude],
        [t.lng!, t.lat!],
      ];
      return;
    }
    final profile = switch (widget.tour.transportMode) {
      'cycling' => 'cycling',
      'driving' => 'driving',
      _ => 'walking',
    };
    try {
      final url = Uri.parse(
          'https://api.mapbox.com/directions/v5/mapbox/$profile/'
          '${pos.longitude},${pos.latitude};${t.lng},${t.lat}'
          '?geometries=geojson&overview=full&access_token=$_mapboxToken');
      final res = await http.get(url).timeout(const Duration(seconds: 8));
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final route = (json['routes'] as List?)?.firstOrNull;
      if (route == null || seq != _manualFetchSeq) return;
      final coords = route['geometry']?['coordinates'];
      if (coords is List) {
        _manualRoute = [
          for (final c in coords)
            if (c is List && c.length >= 2)
              [(c[0] as num).toDouble(), (c[1] as num).toDouble()],
        ];
      }
      final dist = (route['distance'] as num?)?.toDouble();
      if (dist != null && mounted) setState(() => _targetDist = dist);
      final p = _lastPos;
      if (p != null) _updateManualLine(p);
    } catch (_) {
      // Straight-line fallback already drawn by _updateManualLine.
    }
  }

  Future<void> _updateManualLine(geo.Position pos) async {
    final map = _map;
    if (map == null) return;
    if (_targetIdx < 0) {
      _manualRoute = [];
      // Clear unless the head-to-start phase owns the dashed line.
      if (_headingToStart != true && !_guidingBack) {
        try {
          await map.style.setStyleSourceProperty(
              'to-start', 'data', _lineFeature(const []));
        } catch (_) {}
      }
      return;
    }
    final t = widget.stops[_targetIdx];
    final d = _haversine(pos.latitude, pos.longitude, t.lat!, t.lng!);
    if (mounted) setState(() => _targetDist = d);
    // Re-fetch the road route if the user drifted from where it was fetched.
    final anchor = _manualFetchedAt;
    if (anchor == null ||
        _haversine(pos.latitude, pos.longitude, anchor.latitude,
                anchor.longitude) >
            150) {
      _fetchManualRoute(pos);
    }
    try {
      await map.style.setStyleSourceProperty(
          'to-start',
          'data',
          _lineFeature(_manualRoute.length >= 2
              ? _manualRoute
              : [
                  [pos.longitude, pos.latitude],
                  [t.lng!, t.lat!],
                ]));
    } catch (_) {}
  }

  // ---------- Pacing ----------

  int get _plannedMinutes =>
      (widget.tour.estMinutes ?? 0) +
      widget.stops.fold<int>(0, (a, s) => a + s.dwellMinutes);

  Future<void> _maybeAskDeadline() async {
    // Only bother for genuinely long day-tours.
    if (_plannedMinutes < 240 || !mounted) return;
    final wantsTime = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PassimColors.ink,
        title: Text(tr('end_time_q'),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w900)),
        content: Text(
            '~${(_plannedMinutes / 60).toStringAsFixed(1)} h',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('no_time_goal'),
                style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: DykColors.yellow,
                foregroundColor: DykColors.black),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('pick_time')),
          ),
        ],
      ),
    );
    if (wantsTime != true || !mounted) return;
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (now.hour + 6) % 24, minute: 0),
    );
    if (picked == null) return;
    final n = DateTime.now();
    var dl = DateTime(n.year, n.month, n.day, picked.hour, picked.minute);
    if (dl.isBefore(n)) dl = dl.add(const Duration(days: 1));
    _deadline = dl;
  }

  void _checkPace() {
    final dl = _deadline;
    if (dl == null || !mounted || _completing) return;
    final rem = _remaining;
    if (rem.isEmpty) return;
    // Remaining travel: route share not yet covered, plus remaining dwells.
    final total = widget.stops.length;
    final travelLeft = _routeCoords.length >= 2
        ? (widget.tour.estMinutes ?? 0) *
            (1 - _progressIdx / _routeCoords.length)
        : (widget.tour.estMinutes ?? 0) * rem.length / total;
    final dwellLeft = rem.fold<int>(0, (a, s) => a + s.dwellMinutes);
    final eta =
        DateTime.now().add(Duration(minutes: (travelLeft + dwellLeft).round()));
    if (!eta.isAfter(dl.subtract(const Duration(minutes: 15)))) return;
    // Nudge at most once per visited stop.
    if (_lastNudgeAt == _visited.length) return;
    _lastNudgeAt = _visited.length;
    final overloaded = eta.isAfter(dl.add(const Duration(minutes: 30)));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 6),
      backgroundColor: DykColors.yellow,
      content: Text(overloaded ? tr('time_tight') : tr('time_nudge'),
          style: const TextStyle(
              color: DykColors.black, fontWeight: FontWeight.w800)),
      action: overloaded
          ? SnackBarAction(
              label: tr('stop_list'),
              textColor: DykColors.black,
              onPressed: _showStopList,
            )
          : null,
    ));
  }

  void _parseRoute() {
    final geoJson = widget.tour.routeGeojson;
    final coords = geoJson?['coordinates'];
    if (coords is! List) return;
    _routeCoords = [
      for (final c in coords)
        if (c is List && c.length >= 2)
          [(c[0] as num).toDouble(), (c[1] as num).toDouble()],
    ];
  }

  Future<void> _loadProgress() async {
    final visited = await widget.repo.loadTourProgress(widget.tour.id);
    if (mounted) setState(() => _visited = visited);
  }

  // ---------- Map setup ----------

  /// DYK puck drawn at runtime: soft gold halo, white ring, gold core and a
  /// heading wedge — matches the pins and the pulse.
  Future<Uint8List> _buildPuckImage() async {
    const size = 140.0;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    const center = Offset(70, 70);
    // Halo.
    canvas.drawCircle(
        center,
        66,
        Paint()
          ..shader = ui.Gradient.radial(center, 66, [
            PassimColors.brand.withValues(alpha: 0.35),
            PassimColors.brand.withValues(alpha: 0.0),
          ]));
    // Heading wedge (points up; the SDK rotates the image with bearing).
    final wedge = Path()
      ..moveTo(70, 14)
      ..lineTo(56, 44)
      ..lineTo(84, 44)
      ..close();
    canvas.drawPath(wedge, Paint()..color = PassimColors.brand);
    canvas.drawPath(
        wedge,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = PassimColors.ink);
    // White ring + gold core + dark center dot.
    canvas.drawCircle(center, 27, Paint()..color = Colors.white);
    canvas.drawCircle(center, 21, Paint()..color = PassimColors.brand);
    canvas.drawCircle(center, 7, Paint()..color = PassimColors.ink);
    final img = await rec.endRecording().toImage(140, 140);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  void _onMapCreated(MapboxMap map) async {
    _map = map;
    await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await map.location.updateSettings(LocationComponentSettings(
      enabled: true,
      pulsingEnabled: false, // the halo is baked into the puck
      puckBearingEnabled: true,
      locationPuck: LocationPuck(
        locationPuck2D: DefaultLocationPuck2D(
            topImage: await _buildPuckImage()),
      ),
    ));
    await _addRouteLayers(map);
    // Fixed tours keep the loop hidden until the user reaches the start;
    // flip visibility off here, on again in _setRevealed.
    if (!_revealed) {
      for (final id in [
        'route-glow',
        'route-traveled-line',
        'route-casing',
        'route-line',
        'route-arrows',
      ]) {
        try {
          await map.style.setStyleLayerProperty(id, 'visibility', 'none');
        } catch (_) {}
      }
    }
    _points = await map.annotations.createPointAnnotationManager();
    await _drawStops();
    _startLocationWatch();
  }

  String _lineFeature(List<List<double>> coords) => coords.length < 2
      ? '{"type":"FeatureCollection","features":[]}'
      : jsonEncode({
          'type': 'Feature',
          'geometry': {'type': 'LineString', 'coordinates': coords},
          'properties': {},
        });

  // Add a layer beneath the location puck so the user's dot always sits on
  // top of our lines; falls back to a plain add if the puck layer is absent.
  Future<void> _addBelowPuck(MapboxMap map, Layer layer) async {
    try {
      await map.style.addLayerAt(layer,
          LayerPosition(below: 'mapbox-location-indicator-layer'));
    } catch (_) {
      try {
        await map.style.addLayer(layer);
      } catch (_) {}
    }
  }

  Future<void> _addRouteLayers(MapboxMap map) async {
    // Subtle 3D buildings — rise with zoom, sit under all our lines.
    try {
      await map.style.addStyleLayer(
          jsonEncode({
            'id': '3d-buildings',
            'source': 'composite',
            'source-layer': 'building',
            'type': 'fill-extrusion',
            'minzoom': 14.5,
            'paint': {
              // Most OSM buildings lack a height value — give them a
              // plausible 12 m fallback so whole blocks rise, not just
              // the few surveyed landmarks.
              'fill-extrusion-color': '#3B3B3B',
              'fill-extrusion-height': [
                'interpolate', ['linear'], ['zoom'],
                14.5, 0,
                15.3, ['coalesce', ['get', 'height'], 12],
              ],
              'fill-extrusion-base': ['coalesce', ['get', 'min_height'], 0],
              'fill-extrusion-opacity': 0.75,
              'fill-extrusion-vertical-gradient': true,
            },
          }),
          null);
    } catch (_) {}
    if (_routeCoords.length < 2) return;
    // Dashed guide from the user's position to the start of the loop.
    await map.style.addSource(
        GeoJsonSource(id: 'to-start', data: _lineFeature(const [])));
    await _addBelowPuck(map, LineLayer(
      id: 'to-start-line',
      sourceId: 'to-start',
      lineColor: PassimColors.brandArgb,
      lineWidth: 4.0,
      lineOpacity: 0.85,
      lineDasharray: [1.5, 2.0],
      lineJoin: LineJoin.ROUND,
      lineCap: LineCap.ROUND,
    ));
    await map.style.addSource(
        GeoJsonSource(id: 'route-traveled', data: _lineFeature(const [])));
    await map.style.addSource(
        GeoJsonSource(id: 'route-remaining', data: _lineFeature(_routeCoords)));

    // Soft outer glow beneath everything — the premium-GPS feel.
    await _addBelowPuck(map, LineLayer(
      id: 'route-glow',
      sourceId: 'route-remaining',
      lineColor: PassimColors.brandArgb,
      lineWidth: 16.0,
      lineOpacity: 0.15,
      lineBlur: 4.0,
      lineJoin: LineJoin.ROUND,
      lineCap: LineCap.ROUND,
    ));
    // Traveled part: dimmed gray.
    await _addBelowPuck(map, LineLayer(
      id: 'route-traveled-line',
      sourceId: 'route-traveled',
      lineColor: 0xFF6E6E6E,
      lineWidth: 5.0,
      lineOpacity: 0.6,
      lineJoin: LineJoin.ROUND,
      lineCap: LineCap.ROUND,
    ));
    // Remaining: dark casing + DYK yellow.
    await _addBelowPuck(map, LineLayer(
      id: 'route-casing',
      sourceId: 'route-remaining',
      lineColor: PassimColors.inkArgb,
      lineWidth: 9.0,
      lineJoin: LineJoin.ROUND,
      lineCap: LineCap.ROUND,
    ));
    await _addBelowPuck(map, LineLayer(
      id: 'route-line',
      sourceId: 'route-remaining',
      lineColor: PassimColors.brandArgb,
      lineWidth: 6.0,
      lineJoin: LineJoin.ROUND,
      lineCap: LineCap.ROUND,
    ));
    // Direction arrows along the remaining route. Plain ASCII '>' — fancier
    // glyphs (›, ▶) are missing from the map font and render as nothing.
    // Hop-on loops are direction-free: walk either way, so no arrows.
    if (widget.tour.startMode == 'hop_on') return;
    await _addBelowPuck(map, SymbolLayer(
      id: 'route-arrows',
      sourceId: 'route-remaining',
      textField: '>',
      textSize: 17.0,
      textColor: PassimColors.inkArgb,
      symbolPlacement: SymbolPlacement.LINE,
      symbolSpacing: 34.0,
      textAllowOverlap: true,
      textIgnorePlacement: true,
      textRotationAlignment: TextRotationAlignment.MAP,
      textKeepUpright: false,
      textFont: ['DIN Pro Bold', 'Arial Unicode MS Bold'],
    ));
  }

  Uint8List? _pinBytes;
  // Photo pins, built once per stop from its image (yellow-ringed circle).
  final Map<String, Uint8List> _photoPins = {};


  Future<void> _drawStops() async {
    final points = _points;
    if (points == null) return;
    _pinBytes ??=
        (await rootBundle.load('assets/images/badges/history.png'))
            .buffer
            .asUint8List();
    // Build missing photo pins first (cached across redraws).
    for (final s in widget.stops) {
      final img = s.image;
      if (img == null || img.isEmpty || _photoPins.containsKey(s.id)) continue;
      final pin = await buildPhotoPin(img);
      if (pin != null) _photoPins[s.id] = pin;
    }
    await points.deleteAll();
    for (var i = 0; i < widget.stops.length; i++) {
      final s = widget.stops[i];
      if (s.lat == null || s.lng == null) continue;
      final isStart = i == 0;
      // Fixed tour, not yet at the start: only the START pin is shown —
      // plus the manual target, so a "next stop" jump has a visible goal.
      if (!_revealed && !isStart && i != _targetIdx) continue;
      final isEnd = i == widget.stops.length - 1;
      // Hop-on loops have no fixed start/end — plain numbered pins.
      final isLoop = widget.tour.startMode == 'hop_on';
      final label = isLoop
          ? '${i + 1}. ${s.title ?? ''}'
          : isStart
              ? (_revealed
                  ? 'START · ${s.title ?? ''}'
                  : tr('tour_starts_here'))
              : isEnd
                  ? 'END · ${s.title ?? ''}'
                  : '${i + 1}. ${s.title ?? ''}';
      final photo = _photoPins[s.id];
      await points.create(PointAnnotationOptions(
        geometry: Point(coordinates: Position(s.lng!, s.lat!)),
        image: photo ?? _pinBytes,
        iconSize: photo != null
            ? (_visited.contains(s.id) ? 0.28 : 0.38)
            : (_visited.contains(s.id) ? 0.13 : 0.18),
        iconAnchor: IconAnchor.BOTTOM,
        iconOpacity: _visited.contains(s.id) ? 0.55 : 1.0,
        textField: label,
        textAnchor: TextAnchor.TOP,
        textOffset: [0, 0.6],
        textSize: 12,
        textColor: isStart && !isLoop ? PassimColors.brandArgb : PassimColors.whiteArgb,
        textHaloColor: 0xFF000000,
        textHaloWidth: 1.5,
      ));
    }
  }

  // ---------- Position handling ----------

  void _startLocationWatch() {
    // The stream below only emits after ~8 m of movement, so a user standing
    // still at tour start would never trigger the guide phase — grab one fix
    // immediately.
    geo.Geolocator.getCurrentPosition(
            desiredAccuracy: geo.LocationAccuracy.high)
        .then((pos) {
      if (mounted) _onPosition(pos);
    }).catchError((_) {});
    _posSub = geo.Geolocator.getPositionStream(
      locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high, distanceFilter: 8),
    ).listen(_onPosition);
  }

  int _nearestRouteIndex(double lng, double lat) {
    var best = 0;
    var bestD = double.infinity;
    for (var i = 0; i < _routeCoords.length; i++) {
      final dx = _routeCoords[i][0] - lng;
      final dy = _routeCoords[i][1] - lat;
      final d = dx * dx + dy * dy;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  double _haversine(double lat1, double lng1, double lat2, double lng2) =>
      geo.Geolocator.distanceBetween(lat1, lng1, lat2, lng2);

  TourStop? get _startStop {
    for (final s in widget.stops) {
      if (s.lat != null && s.lng != null) return s;
    }
    return null;
  }

  TourStop? _nearestStop(geo.Position pos) {
    TourStop? best;
    var bestD = double.infinity;
    for (final s in widget.stops) {
      if (s.lat == null || s.lng == null) continue;
      final d = _haversine(pos.latitude, pos.longitude, s.lat!, s.lng!);
      if (d < bestD) {
        bestD = d;
        best = s;
      }
    }
    return best;
  }

  // Show/hide the loop layers + full stop set (fixed tours keep the loop
  // hidden until the user reaches the start).
  Future<void> _setRevealed(bool value) async {
    if (_revealed == value) return;
    _revealed = value;
    final map = _map;
    if (map == null) return;
    const layers = [
      'route-glow',
      'route-traveled-line',
      'route-casing',
      'route-line',
      'route-arrows',
    ];
    for (final id in layers) {
      try {
        await map.style.setStyleLayerProperty(
            id, 'visibility', value ? 'visible' : 'none');
      } catch (_) {}
    }
    await _drawStops();
  }

  /// Walk-route for the guide phase — the dashed line follows streets, not
  /// the crow-flies line (which is never walkable).
  Future<void> _fetchGuideRoute(geo.Position pos, TourStop target) async {
    final seq = ++_guideFetchSeq;
    _guideFetchedAt = pos;
    if (widget.tour.transportMode == 'boat') return; // straight is honest
    final profile = switch (widget.tour.transportMode) {
      'cycling' => 'cycling',
      'driving' => 'driving',
      _ => 'walking',
    };
    try {
      final url = Uri.parse(
          'https://api.mapbox.com/directions/v5/mapbox/$profile/'
          '${pos.longitude},${pos.latitude};${target.lng},${target.lat}'
          '?geometries=geojson&overview=full&access_token=$_mapboxToken');
      final res = await http.get(url).timeout(const Duration(seconds: 8));
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final route = (json['routes'] as List?)?.firstOrNull;
      if (route == null || seq != _guideFetchSeq) return;
      final coords = route['geometry']?['coordinates'];
      if (coords is List) {
        _guideRouteCoords = [
          for (final c in coords)
            if (c is List && c.length >= 2)
              [(c[0] as num).toDouble(), (c[1] as num).toDouble()],
        ];
      }
      final dist = (route['distance'] as num?)?.toDouble();
      if (dist != null && mounted) setState(() => _startDistance = dist);
      final p = _lastPos;
      if (p != null) _updateToStartLine(p);
    } catch (_) {}
  }

  Future<void> _updateToStartLine(geo.Position pos) async {
    final map = _map;
    final target = _guideTarget ?? _startStop;
    if (map == null || target == null) return;
    final show = _headingToStart == true || _guidingBack;
    if (show) {
      final anchor = _guideFetchedAt;
      if (anchor == null ||
          _haversine(pos.latitude, pos.longitude, anchor.latitude,
                  anchor.longitude) >
              150) {
        _fetchGuideRoute(pos, _guidingBack ? _startStop! : target);
      }
    }
    try {
      final data = show
          ? _lineFeature(_guideRouteCoords.length >= 2
              ? _guideRouteCoords
              : [
                  [pos.longitude, pos.latitude],
                  [target.lng!, target.lat!],
                ])
          : _lineFeature(const []);
      await map.style.setStyleSourceProperty('to-start', 'data', data);
    } catch (_) {}
  }

  double _tourMeters = 0;
  geo.Position? _lastStepPos;

  void _onPosition(geo.Position pos) {
    // Steps walked on this tour (GPS deltas; jumps filtered).
    final prev = _lastStepPos;
    if (prev != null) {
      final d = _haversine(
          prev.latitude, prev.longitude, pos.latitude, pos.longitude);
      if (d >= 3 && d <= 300) {
        _tourMeters += d;
        StepStore.addMeters(d);
      }
    }
    _lastStepPos = pos;
    _lastPos = pos;

    // Guide phase: to the entry point (fixed → stop 1, hop-on → nearest),
    // or back to the start after finishing a fixed tour.
    if (_headingToStart == null) {
      // First fix: pick the target and decide if the guide phase is needed.
      _guideTarget = widget.tour.startMode == 'hop_on'
          ? _nearestStop(pos)
          : _startStop;
      final t = _guideTarget;
      if (t != null) {
        final d = _haversine(pos.latitude, pos.longitude, t.lat!, t.lng!);
        final threshold = t.arrivalRadiusMeters > 100
            ? t.arrivalRadiusMeters * 1.0
            : 100.0;
        _headingToStart = d > threshold;
        // Fixed tour + far away → keep the loop hidden until arrival.
        if (_headingToStart == false) _setRevealed(true);
      } else {
        _headingToStart = false;
      }
    }
    final target = _guidingBack ? _startStop : _guideTarget;
    if (target != null && (_headingToStart == true || _guidingBack)) {
      final d = _haversine(
          pos.latitude, pos.longitude, target.lat!, target.lng!);
      final threshold = target.arrivalRadiusMeters > 100
          ? target.arrivalRadiusMeters * 1.0
          : 100.0;
      if (d <= threshold) {
        if (_guidingBack) {
          // Back at the start after a completed tour — celebrate.
          _guidingBack = false;
          _updateToStartLine(pos);
          if (mounted) {
            Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (_) => TourCompleteScreen(
                  tourTitle: widget.tour.title,
                  steps: StepStore.stepsFromMeters(_tourMeters),
                  minutes:
                      DateTime.now().difference(_startedAt).inMinutes,
                  stopsVisited: _visited.length,
                  stopsTotal: widget.stops.length),
            ));
          }
          return;
        }
        _headingToStart = false; // arrived - hand over to loop navigation
        _setRevealed(true);
      }
      if (mounted) setState(() => _startDistance = d);
      _updateToStartLine(pos);
    }

    // Arrival check. Paused while dwelling; skipped stops never trigger.
    if (!_dwelling) {
      for (final s in widget.stops) {
        if (s.lat == null || s.lng == null) continue;
        if (_visited.contains(s.id) || _skippedLive.contains(s.id)) continue;
        final meters =
            _haversine(pos.latitude, pos.longitude, s.lat!, s.lng!);
        if (meters <= s.arrivalRadiusMeters) {
          _arriveAt(s);
          break;
        }
      }
    }

    // Manual-target dashed guidance.
    if (_targetIdx >= 0) _updateManualLine(pos);

    // Hop-on loops have no direction — keep the whole loop yellow and skip
    // turn-by-turn (the banner shows the nearest unvisited stop instead).
    if (_routeCoords.length >= 2 && widget.tour.startMode != 'hop_on') {
      // Progress along the loop: dim what's behind, keep ahead yellow.
      final idx = _nearestRouteIndex(pos.longitude, pos.latitude);
      // Only ever move forward (small GPS jitter shouldn't rewind the line).
      if (idx > _progressIdx && (idx - _progressIdx) < 200) {
        _progressIdx = idx;
        _updateRouteSplit();
      }

      // Current turn instruction: first maneuver still ahead of us.
      if (_steps.isNotEmpty) {
        var stepIdx = _steps.length - 1;
        for (var i = 0; i < _steps.length; i++) {
          if (_stepRouteIdx[i] >= _progressIdx) {
            stepIdx = i;
            break;
          }
        }
        final loc = _steps[stepIdx]['location'] as List;
        final dist = _haversine(pos.latitude, pos.longitude,
            (loc[1] as num).toDouble(), (loc[0] as num).toDouble());
        if (mounted) {
          setState(() {
            _currentStep = stepIdx;
            _stepDistance = dist;
          });
        }
      }
    }

    // GPS-style follow camera.
    if (_follow && _map != null) {
      _map!.easeTo(
        CameraOptions(
          center: Point(coordinates: Position(pos.longitude, pos.latitude)),
          zoom: 16.5,
          pitch: 45,
          bearing: pos.heading >= 0 ? pos.heading : null,
        ),
        MapAnimationOptions(duration: 900),
      );
    }
  }

  Future<void> _updateRouteSplit() async {
    final map = _map;
    if (map == null || _routeCoords.length < 2) return;
    try {
      final traveled = _routeCoords.sublist(0, _progressIdx + 1);
      final remaining = _routeCoords.sublist(_progressIdx);
      await map.style
          .setStyleSourceProperty('route-traveled', 'data', _lineFeature(traveled));
      await map.style.setStyleSourceProperty(
          'route-remaining', 'data', _lineFeature(remaining));
    } catch (_) {}
  }

  // ---------- Camera controls ----------

  Future<void> _showOverview() async {
    final map = _map;
    if (map == null) return;
    setState(() => _follow = false);
    final pts = <Point>[
      for (final c in _routeCoords)
        Point(coordinates: Position(c[0], c[1])),
      for (final s in widget.stops)
        if (s.lat != null && s.lng != null)
          Point(coordinates: Position(s.lng!, s.lat!)),
    ];
    if (pts.isEmpty) return;
    try {
      final cam = await map.cameraForCoordinates(
        pts,
        MbxEdgeInsets(top: 180, left: 50, bottom: 160, right: 50),
        null,
        null,
      );
      cam.pitch = 0;
      cam.bearing = 0;
      await map.flyTo(cam, MapAnimationOptions(duration: 800));
    } catch (_) {}
  }

  void _recenter() {
    setState(() => _follow = true);
    final pos = _lastPos;
    if (pos != null) _onPosition(pos);
  }

  // ---------- Arrival / completion (unchanged behaviour) ----------

  Future<void> _arriveAt(TourStop s) async {
    // Gold pulse + haptics that follow it: hard hit as the glow blooms,
    // two softer ones as the ring expands and fades.
    setState(() => _pulseSeq++);
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 300),
        () => HapticFeedback.mediumImpact());
    Future.delayed(const Duration(milliseconds: 600),
        () => HapticFeedback.lightImpact());
    Future.delayed(const Duration(milliseconds: 1000),
        () => HapticFeedback.lightImpact());
    if (_lifecycle != AppLifecycleState.resumed) {
      _notifs.show(
        s.id.hashCode,
        '${tr('welcome_stop')} ${s.title ?? ''}',
        tr('arrival_notif_body'),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'hotspot_channel',
            'Hotspot Alerts',
            importance: Importance.high,
            priority: Priority.high,
            color: PassimColors.brand,
            colorized: true,
          ),
          iOS: DarwinNotificationDetails(presentSound: true),
        ),
      );
    }
    setState(() {
      _visited = {..._visited, s.id};
      _dwelling = true;
      // Reached the manual target → back to automatic loop-following.
      if (_targetIdx >= 0 && widget.stops[_targetIdx].id == s.id) {
        _targetIdx = -1;
      }
    });
    await widget.repo.recordTourVisit(widget.tour.id, s.id);
    _drawStops(); // dim the visited pin
    // Let the pulse land before the sheet covers the map.
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    _showStopSheet(s);
  }

  /// Called when the arrival sheet closes ("Let's move on" or swiped away).
  void _onLeaveStop() {
    if (!mounted) return;
    setState(() => _dwelling = false);
    _maybeComplete();
  }

  void _maybeComplete() {
    if (_remaining.isNotEmpty || _visited.isEmpty) return;
    if (!_completing) {
      _completing = true;
      Future.delayed(const Duration(milliseconds: 600), () async {
        if (!mounted) return;
        // Fixed tour ending away from the start: offer guidance back.
        final start = _startStop;
        final pos = _lastPos;
        final farFromStart = widget.tour.startMode == 'fixed' &&
            start != null &&
            pos != null &&
            _haversine(pos.latitude, pos.longitude, start.lat!, start.lng!) >
                120;
        if (farFromStart) {
          final goBack = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: PassimColors.ink,
              title: Text(tr('tour_done_title'),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w900)),
              content: Text(tr('tour_back_q'),
                  style: const TextStyle(color: Colors.white70)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(tr('im_done'),
                      style: const TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: DykColors.yellow,
                      foregroundColor: DykColors.black),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(tr('show_way')),
                ),
              ],
            ),
          );
          if (!mounted) return;
          if (goBack == true) {
            setState(() {
              _guidingBack = true;
              _completing = false; // stay on the map while walking back
            });
            _guideRouteCoords = [];
            _guideFetchedAt = null;
            final p = _lastPos;
            if (p != null) _updateToStartLine(p);
            return;
          }
        }
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => TourCompleteScreen(
              tourTitle: widget.tour.title,
              steps: StepStore.stepsFromMeters(_tourMeters),
              minutes: DateTime.now().difference(_startedAt).inMinutes,
              stopsVisited: _visited.length,
              stopsTotal: widget.stops.length),
        ));
      });
    }
  }

  void _showStopSheet(TourStop s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: PassimColors.ink,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _StopSheet(
        stop: s,
        audioService: widget.audioService,
        onReadMore: () => _openStopDetail(s),
      ),
    ).whenComplete(_onLeaveStop);
  }

  // City hotspots, loaded lazily the first time a linked stop is opened.
  List<Hotspot>? _cityHotspots;

  /// Hotspot-linked stops open the hotspot's page; venue stops get their
  /// own detail page built from the stop's content.
  Future<void> _openStopDetail(TourStop s) async {
    if (s.hotspotId == null) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (ctx) => StopDetailScreen(
          stop: s,
          audioService: widget.audioService,
          onContinueTour: () => Navigator.of(ctx)
            ..pop() // detail page
            ..pop(), // arrival sheet → resumes the tour
        ),
      ));
      return;
    }
    await _openHotspotPage(s);
  }

  Future<void> _openHotspotPage(TourStop s) async {
    _cityHotspots ??= await widget.repo.loadHotspots(widget.tour.citypackId);
    final h =
        _cityHotspots!.where((x) => x.id == s.hotspotId).firstOrNull;
    if (h == null || !mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) => HotspotDetailScreen(
        hotspot: h,
        audioService: widget.audioService,
        onContinueTour: () => Navigator.of(ctx)
          ..pop() // detail page
          ..pop(), // arrival sheet → resumes the tour
      ),
    ));
  }

  // ---------- Stop list sheet (jump / skip mid-tour) ----------

  void _showStopList() {
    showModalBottomSheet(
      context: context,
      backgroundColor: PassimColors.ink,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 6),
                child: Text(tr('stop_list'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900)),
              ),
              for (var i = 0; i < widget.stops.length; i++)
                _stopListRow(ctx, setSheet, i),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stopListRow(
      BuildContext ctx, void Function(void Function()) setSheet, int i) {
    final s = widget.stops[i];
    final visited = _visited.contains(s.id);
    final skipped = _skippedLive.contains(s.id);
    final isTarget = _targetIdx == i;
    return ListTile(
      enabled: !visited && !skipped && s.lat != null,
      onTap: visited || skipped || s.lat == null
          ? null
          : () {
              Navigator.pop(ctx);
              _setTarget(i);
            },
      leading: CircleAvatar(
        radius: 15,
        backgroundColor: visited
            ? Colors.white24
            : (isTarget ? DykColors.yellow : PassimColors.surface),
        child: visited
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : Text('${i + 1}',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: isTarget ? DykColors.black : Colors.white)),
      ),
      title: Text(
        s.title ?? 'Stop ${i + 1}',
        style: TextStyle(
          color: skipped ? Colors.white30 : Colors.white,
          fontWeight: FontWeight.w700,
          decoration: skipped ? TextDecoration.lineThrough : null,
          decorationColor: Colors.white30,
        ),
      ),
      subtitle: visited
          ? Text(tr('revisit_hint'),
              style: const TextStyle(color: Colors.white38, fontSize: 12))
          : skipped
              ? Text(tr('skipped'),
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 12))
              : null,
      trailing: visited
          ? null
          : IconButton(
              icon: Icon(
                skipped ? Icons.visibility_off : Icons.visibility,
                color: skipped ? Colors.white30 : Colors.white54,
                size: 20,
              ),
              onPressed: () {
                _toggleSkipLive(s);
                setSheet(() {});
              },
            ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _posSub?.cancel();
    _paceTimer?.cancel();
    SharedPreferences.getInstance()
        .then((p) => p.setBool('tour_active', false));
    super.dispose();
  }

  // ---------- Navigation banner ----------

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

  String _fmtDist(double m) =>
      m >= 1000 ? '${(m / 1000).toStringAsFixed(1)} km' : '${m.round()} m';

  Widget _navBanner() {
    // Dwelling at a stop: calm "paused" chip instead of turn instructions.
    if (_dwelling) {
      return _bannerShell(
        icon: Icons.local_cafe,
        distance: 0,
        text: tr('tour_paused_here'),
      );
    }
    // Manual target: dashed-line guidance with the stop's name.
    if (_targetIdx >= 0) {
      final t = widget.stops[_targetIdx];
      return _bannerShell(
        icon: Icons.sports_score,
        distance: _targetDist,
        text: '${tr('next_stop')}: ${t.title ?? '${_targetIdx + 1}'}',
      );
    }
    // Guide phase: to the entry point, or back to the start when done.
    if (_headingToStart == true || _guidingBack) {
      final target = _guidingBack ? _startStop : _guideTarget;
      final name = target?.title;
      final isNearestJoin =
          widget.tour.startMode == 'hop_on' && !_guidingBack && name != null;
      return _bannerShell(
        icon: Icons.sports_score,
        distance: _startDistance,
        text: isNearestJoin ? name : tr('head_to_start'),
      );
    }
    // Direction-free loop: point at the closest stop you haven't seen yet.
    if (widget.tour.startMode == 'hop_on') {
      final pos = _lastPos;
      if (pos == null) return const SizedBox.shrink();
      TourStop? best;
      var bestD = double.infinity;
      for (final s in _remaining) {
        final d = _haversine(pos.latitude, pos.longitude, s.lat!, s.lng!);
        if (d < bestD) {
          bestD = d;
          best = s;
        }
      }
      if (best == null) return const SizedBox.shrink();
      return _bannerShell(
        icon: Icons.sports_score,
        distance: bestD,
        text: best.title ?? tr('next_stop'),
      );
    }
    if (_steps.isEmpty) return const SizedBox.shrink();
    final step = _steps[_currentStep];
    return _bannerShell(
      icon: _maneuverIcon(step),
      distance: _stepDistance,
      text: (step['instruction'] as String?) ?? '',
    );
  }

  Widget _bannerShell(
      {required IconData icon,
      required double distance,
      required String text}) {

    if (_navMinimized) {
      return GestureDetector(
        onTap: () => setState(() => _navMinimized = false),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: PassimColors.ink,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: DykColors.yellow, width: 1.5),
            boxShadow: const [
              BoxShadow(color: Colors.black45, blurRadius: 8),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: DykColors.yellow, size: 22),
              const SizedBox(width: 8),
              Text(_fmtDist(distance),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15)),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more, color: Colors.white54, size: 18),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => setState(() => _navMinimized = true),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: PassimColors.ink,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DykColors.yellow, width: 1.5),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: DykColors.yellow,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: DykColors.black, size: 30),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_fmtDist(distance),
                      style: const TextStyle(
                          color: DykColors.yellow,
                          fontWeight: FontWeight.w900,
                          fontSize: 18)),
                  Text(
                    text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 1.25),
                  ),
                ],
              ),
            ),
            const Icon(Icons.expand_less, color: Colors.white38, size: 20),
          ],
        ),
      ),
    );
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    final located =
        widget.stops.where((s) => s.lat != null && s.lng != null).toList();
    final centerLng = located.isNotEmpty ? located.first.lng! : 2.6500;
    final centerLat = located.isNotEmpty ? located.first.lat! : 39.5690;
    final done = _visited.length;
    final total = widget.stops.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(widget.tour.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: PassimColors.ink,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Overview',
            icon: const Icon(Icons.map_outlined),
            onPressed: _showOverview,
          ),
        ],
      ),
      body: Stack(
        children: [
          MapWidget(
            key: const ValueKey('active_tour_map'),
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(centerLng, centerLat)),
              zoom: 15.0,
            ),
            styleUri: MapboxStyles.DARK,
            onMapCreated: _onMapCreated,
            onScrollListener: (_) {
              // Manual pan pauses follow mode.
              if (_follow && mounted) setState(() => _follow = false);
            },
          ),

          // Gold-pulse arrival flash (haptics fire in sync in _arriveAt).
          if (_pulseSeq > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(_pulseSeq),
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1800),
                  curve: Curves.easeOut,
                  builder: (context, t, _) => CustomPaint(
                    painter: _GoldPulsePainter(t),
                    size: ui.Size.infinite,
                  ),
                ),
              ),
            ),

          // Turn-by-turn banner (tap to minimize/expand).
          Positioned(
            top: 12,
            left: 12,
            right: _navMinimized ? null : 12,
            child: Align(
              alignment: Alignment.topLeft,
              child: _navBanner(),
            ),
          ),

          // Re-center FAB when follow mode is off.
          if (!_follow)
            Positioned(
              right: 16,
              bottom: 96 + MediaQuery.of(context).padding.bottom,
              child: FloatingActionButton.small(
                backgroundColor: DykColors.yellow,
                foregroundColor: DykColors.black,
                onPressed: _recenter,
                child: const Icon(Icons.my_location),
              ),
            ),

          // Progress card.
          Positioned(
            left: 16,
            right: 16,
            bottom: 16 + MediaQuery.of(context).padding.bottom,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: PassimColors.ink,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: DykColors.yellow, width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.chevron_left,
                            color: Colors.white70),
                        onPressed: () => _stepTarget(-1),
                      ),
                      widget.tour.transportMode == 'walking'
                          ? const FootstepsIcon(size: 20)
                          : Icon(transportIcon(widget.tour.transportMode),
                              color: DykColors.yellow, size: 20),
                      Expanded(
                        child: GestureDetector(
                          onTap: _showStopList,
                          child: Text(
                            _targetIdx >= 0
                                ? '${_targetIdx + 1}/$total · ${widget.stops[_targetIdx].title ?? ''}'
                                : '$done / $total ${tr('stops_done')}',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: Colors.white),
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.chevron_right,
                            color: Colors.white70),
                        onPressed: () => _stepTarget(1),
                      ),
                      GestureDetector(
                        onTap: _showStopList,
                        child: Icon(
                          done >= total
                              ? Icons.check_circle
                              : Icons.format_list_numbered,
                          color: DykColors.yellow,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total > 0 ? done / total : 0,
                      minHeight: 6,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          DykColors.yellow),
                    ),
                  ),
                  if (widget.tour.transportMode == 'walking' &&
                      widget.tour.distanceMeters != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      '${StepStore.fmt(StepStore.stepsFromMeters(_tourMeters))} ${tr('of')} ${StepStore.fmt(StepStore.stepsFromMeters(widget.tour.distanceMeters!))} ${tr('steps_unit')}',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 11.5),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Future<void> _confirmLeave() async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PassimColors.ink,
        title: Text(tr('leave_tour_q'),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w900)),
        content: Text(tr('leave_tour_sub'),
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'quit'),
            child: Text(tr('quit_tour'),
                style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: DykColors.yellow,
                foregroundColor: DykColors.black),
            onPressed: () => Navigator.pop(ctx, 'pause'),
            child: Text(tr('pause_tour')),
          ),
        ],
      ),
    );
    if (action == null || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    if (action == 'pause') {
      await prefs.setString('paused_tour_id', widget.tour.id);
      if (mounted) Navigator.of(context).pop();
      return;
    }
    await prefs.remove('paused_tour_id');
    if (!mounted) return;
    // Quitting after real progress deserves the summary too.
    if (_visited.isNotEmpty) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => TourCompleteScreen(
            tourTitle: widget.tour.title,
            steps: StepStore.stepsFromMeters(_tourMeters),
            minutes: DateTime.now().difference(_startedAt).inMinutes,
            stopsVisited: _visited.length,
            stopsTotal: widget.stops.length),
      ));
    } else {
      Navigator.of(context).pop();
    }
  }
}

class _StopSheet extends StatelessWidget {
  final TourStop stop;
  final AudioService audioService;
  final VoidCallback? onReadMore;
  const _StopSheet(
      {required this.stop, required this.audioService, this.onReadMore});

  @override
  Widget build(BuildContext context) {
    final hasAudio = stop.audioPath != null && stop.audioPath!.isNotEmpty;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Transform.scale(
        scale: v,
        alignment: Alignment.topCenter,
        child: Opacity(opacity: v.clamp(0, 1), child: child),
      ),
      child: Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, 24 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${tr('welcome_stop')} ${stop.title ?? ''}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900)),
          if (stop.dwellMinutes > 0) ...[
            const SizedBox(height: 4),
            Text(
              stop.dwellMinutes >= 60
                  ? '${tr('suggested_stay')}${(stop.dwellMinutes / 60).toStringAsFixed(stop.dwellMinutes % 60 == 0 ? 0 : 1)} h'
                  : '${tr('suggested_stay')}${stop.dwellMinutes} min',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
          const SizedBox(height: 10),
          if (stop.blurb != null)
            Text(stop.blurb!,
                style: const TextStyle(color: Colors.white70, height: 1.4)),
          if (hasAudio) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: DykColors.yellow,
                    foregroundColor: DykColors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12)),
                icon: const Icon(Icons.play_arrow),
                label: Text(tr('play_narration'),
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                onPressed: () => audioService.play(stop.audioPath!,
                    title: stop.title, artUrl: stop.image),
              ),
            ),
          ],
          if (stop.offerText != null) ...[
            const SizedBox(height: 14),
            Text(stop.offerText!,
                style: const TextStyle(
                    color: DykColors.yellow, fontWeight: FontWeight.w700)),
          ],
          if (stop.ctaText != null && stop.ctaUrl != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: DykColors.yellow,
                  side: const BorderSide(color: DykColors.yellow, width: 1.5),
                ),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(stop.ctaText!,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                onPressed: () => launchUrl(Uri.parse(stop.ctaUrl!),
                    mode: LaunchMode.externalApplication),
              ),
            ),
          ],
          if (stop.redeemCode != null && stop.redeemCode!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: DykColors.yellow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: DykColors.black, width: 2),
                ),
                child: Text('CODE: ${stop.redeemCode}',
                    style: const TextStyle(
                        color: DykColors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: 1)),
              ),
            ),
          ],
          if (onReadMore != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: DykColors.yellow,
                  foregroundColor: DykColors.black,
                ),
                icon: const Icon(Icons.auto_stories, size: 20),
                label: Text(tr('read_full_story'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 15)),
                onPressed: onReadMore,
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: onReadMore != null
                ? OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white30),
                    ),
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: Text(tr('continue_tour'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    onPressed: () => Navigator.pop(context),
                  )
                : ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: DykColors.yellow,
                        foregroundColor: DykColors.black),
                    icon: const Icon(Icons.arrow_forward),
                    label: Text('${tr('continue_tour')} →',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 16)),
                    onPressed: () => Navigator.pop(context),
                  ),
          ),
        ],
      ),
      ),
    );
  }
}

/// Radial gold glow + expanding ring, faded in/out over one sweep.
class _GoldPulsePainter extends CustomPainter {
  final double t; // 0..1
  _GoldPulsePainter(this.t);

  @override
  void paint(Canvas canvas, ui.Size size) {
    if (t >= 1) return;
    final fade = (t < 0.25 ? t / 0.25 : (1 - t) / 0.75).clamp(0.0, 1.0);
    final center = Offset(size.width / 2, size.height * 0.55);
    // Soft glow.
    final glow = Paint()
      ..shader = RadialGradient(colors: [
        PassimColors.brand.withValues(alpha: 0.45 * fade),
        PassimColors.brand.withValues(alpha: 0.12 * fade),
        Colors.transparent,
      ], stops: const [0, 0.45, 1])
          .createShader(
              Rect.fromCircle(center: center, radius: size.width * 0.9));
    canvas.drawRect(Offset.zero & size, glow);
    // Two expanding rings, the second trailing the first.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5 * (1 - t) + 1
      ..color = PassimColors.brand.withValues(alpha: (1 - t) * 0.9);
    canvas.drawCircle(center, 20 + t * size.width * 0.8, ring);
    final t2 = ((t - 0.25) / 0.75).clamp(0.0, 1.0);
    if (t2 > 0) {
      final ring2 = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * (1 - t2) + 1
        ..color = PassimColors.brand.withValues(alpha: (1 - t2) * 0.6);
      canvas.drawCircle(center, 20 + t2 * size.width * 0.8, ring2);
    }
  }

  @override
  bool shouldRepaint(_GoldPulsePainter old) => old.t != t;
}
