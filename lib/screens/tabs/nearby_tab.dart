import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide Visibility;
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart' hide Position;
import 'package:geolocator/geolocator.dart' as geo_pos show Position;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../models/hot_deal.dart';
import '../../models/hotspot.dart';
import '../../models/pickpocket_report.dart';
import '../../services/audio_service.dart';
import '../../services/auth_service.dart';
import '../../services/dyk_repository.dart';
import '../../services/entitlements.dart';
import '../../services/saved_store.dart';
import '../../theme/dyk_theme.dart';
import '../../widgets/category_badge.dart';
import '../../widgets/dyk_puck.dart';
import '../../widgets/photo_pin.dart';
import '../deal_detail_screen.dart';
import '../hotspot_detail_screen.dart';
import '../../i18n/i18n.dart';
import '../../services/step_store.dart';

const _categoryMeta = {
  'history': ('🏛️', 'History'),
  'otium': ('🌿', 'Leisure'),
  'headline': ('📖', 'Stories & Legends'),
  'hotdeal': ('🔥', 'Hot Deals'),
};

// Icon ids we try to register as Mapbox style images (each maps to a PNG in
// assets/images/badges/). Missing files are skipped and fall back gracefully.
const _iconIds = [
  'history',
  'history_building',
  'history_work_of_art',
  'history_historical_figure',
  'otium',
  'otium_leisure',
  'otium_art',
  'otium_natural_spaces',
  'funfact',
  'headline',
  'hotdeal',
  'pickpocket',
];

const _srcId = 'dyk_places';

class NearbyTab extends StatefulWidget {
  final List<Hotspot> hotspots;
  final List<HotDeal> deals;
  final AudioService audioService;
  final SavedStore? savedStore;
  final DykRepositoryBase? repo;
  final Entitlements? entitlements;
  final String? citypackId;
  final String? cityName;
  final int cityPriceCents;
  final AuthService? authService;

  const NearbyTab({
    super.key,
    required this.hotspots,
    this.deals = const [],
    required this.audioService,
    this.savedStore,
    this.repo,
    this.entitlements,
    this.citypackId,
    this.cityName,
    this.cityPriceCents = 0,
    this.authService,
  });

  @override
  State<NearbyTab> createState() => _NearbyTabState();
}

class _NearbyTabState extends State<NearbyTab> {
  MapboxMap? _map;
  bool _setupDone = false;
  final Set<String> _registered = {};
  // Hotspots whose first image is registered as a 'photo_<id>' style image.
  final Set<String> _photoPinIds = {};
  List<PickpocketReport> _pickpockets = [];

  final Set<String> _visibleCategories = {
    'history',
    'otium',
    'headline',
    'hotdeal',
  };
  String _search = '';
  final _searchCtrl = TextEditingController();
  bool _panelOpen = false;
  geo_pos.Position? _userPos;

  static const _palmaCenterLng = 2.6500;
  static const _palmaCenterLat = 39.5690;

  @override
  void initState() {
    super.initState();
    Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
        .then((p) {
      if (mounted) setState(() => _userPos = p);
    }).catchError((_) {});
  }

  // When the city switches, the parent passes a new hotspot list — refresh the
  // map source and frame the new city.
  @override
  void didUpdateWidget(covariant NearbyTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.hotspots, widget.hotspots)) {
      _updateSource();
      _fitToHotspots();
    }
  }

  Future<void> _fitToHotspots() async {
    final map = _map;
    if (map == null) return;
    final pts = widget.hotspots
        .map((h) => Point(coordinates: Position(h.lng, h.lat)))
        .toList();
    if (pts.isEmpty) return;
    try {
      final cam = await map.cameraForCoordinates(
        pts,
        MbxEdgeInsets(top: 120, left: 60, bottom: 160, right: 60),
        null,
        null,
      );
      await map.flyTo(cam, MapAnimationOptions(duration: 700));
    } catch (_) {}
  }

  List<Hotspot> get _filtered => widget.hotspots
      .where((h) =>
          _visibleCategories.contains(h.category) &&
          (_search.isEmpty ||
              h.name.toLowerCase().contains(_search.toLowerCase())))
      .toList();

  List<HotDeal> get _filteredDeals => !_visibleCategories.contains('hotdeal')
      ? const []
      : widget.deals
          .where((d) =>
              _search.isEmpty ||
              d.businessName.toLowerCase().contains(_search.toLowerCase()))
          .toList();

  void _onMapCreated(MapboxMap map) async {
    _map = map;
    await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await map.location.updateSettings(LocationComponentSettings(
      enabled: true,
      pulsingEnabled: false, // the halo is baked into the puck
      puckBearingEnabled: true, // compass wedge shows walking direction
      locationPuck: LocationPuck(
        locationPuck2D: DefaultLocationPuck2D(topImage: await buildDykPuck()),
      ),
    ));
  }

  // Runs once the style is ready: register icons, load data, add the
  // clustered source + layers, then center on the user.
  Future<void> _setupMap() async {
    final map = _map;
    if (map == null || _setupDone) return;
    _setupDone = true;

    // Same subtle 3D buildings as the tour map (12 m fallback height).
    try {
      await map.style.addStyleLayer(
          jsonEncode({
            'id': '3d-buildings',
            'source': 'composite',
            'source-layer': 'building',
            'type': 'fill-extrusion',
            'minzoom': 14.5,
            'paint': {
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

    await _registerIcons(map);
    if (widget.repo != null) {
      try {
        _pickpockets = await widget.repo!.loadPickpocketReports();
      } catch (_) {}
    }
    await _addSourceAndLayers(map);
    _buildPhotoPins(map);

    // Center on the user's position (zoom 15) so they see their surroundings.
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      await map.setCamera(CameraOptions(
        center: Point(coordinates: Position(pos.longitude, pos.latitude)),
        zoom: 15.0,
      ));
    } catch (_) {}
  }

  // Decode each badge PNG to premultiplied RGBA and register it as a style
  // image so the symbol layer can pick it via the feature's "icon" property.
  /// Turn each hotspot's first image into a photo pin (lazily, cached) and
  /// refresh the source so pins upgrade from badges to photos as they load.
  Future<void> _buildPhotoPins(MapboxMap map) async {
    var pending = 0;
    for (final h in widget.hotspots) {
      if (h.images.isEmpty || _photoPinIds.contains(h.id)) continue;
      final bytes = await buildPhotoPin(h.images.first);
      if (bytes == null || !mounted) continue;
      try {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        await map.style.addStyleImage(
          'photo_${h.id}',
          // Mapbox treats scale as pixel density: <1 renders LARGER. 0.55
          // lands the 260px canvas at ~60px on screen after the layer's
          // iconSize (0.125) is applied.
          0.55,
          MbxImage(
              width: frame.image.width,
              height: frame.image.height,
              data: bytes),
          false,
          <ImageStretches>[],
          <ImageStretches>[],
          null,
        );
        _photoPinIds.add(h.id);
        pending++;
        if (pending % 8 == 0) await _updateSource();
      } catch (_) {}
    }
    if (pending > 0) await _updateSource();
  }

  Future<void> _registerIcons(MapboxMap map) async {
    for (final id in _iconIds) {
      await _registerOne(map, id);
    }
  }

  Future<void> _registerOne(MapboxMap map, String id) async {
    if (_registered.contains(id)) return;
    // Only our known badge ids map to assets.
    if (!_iconIds.contains(id)) return;
    try {
      final pngBytes =
          (await rootBundle.load('assets/images/badges/$id.png'))
              .buffer
              .asUint8List();
      // Decode only to read the image's dimensions; the native side decodes
      // the PNG bytes itself (same path PointAnnotation uses successfully).
      final codec = await ui.instantiateImageCodec(pngBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      await map.style.addStyleImage(
        id,
        1.0,
        MbxImage(
            width: image.width, height: image.height, data: pngBytes),
        false,
        <ImageStretches>[],
        <ImageStretches>[],
        null,
      );
      _registered.add(id);
    } catch (_) {}
  }

  // Fired by Mapbox when a layer references an image that isn't loaded yet —
  // we (re)register it on demand. Force re-registration even if we think it's
  // already done, because an earlier batch registration may not have stuck.
  void _onStyleImageMissing(StyleImageMissingEventData data) {
    final map = _map;
    if (map == null) return;
    _registered.remove(data.id);
    _registerOne(map, data.id);
  }

  // Pick the icon id from the static asset list (NOT registration status), so
  // a feature always references the right image; the missing-image listener
  // then ensures that image is loaded.
  String _iconFor(String category, String? subcategory) {
    final combo = subcategory != null ? '${category}_$subcategory' : category;
    if (_iconIds.contains(combo)) return combo;
    if (_iconIds.contains(category)) return category;
    return 'history';
  }

  // GeoJSON of all visible places, used for the clustered source.
  String _featureJson() {
    final features = <Map<String, dynamic>>[];
    for (final h in _filtered) {
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [h.lng, h.lat],
        },
        'properties': {
          // Airbnb-style: the place's own photo as the pin when available.
          'icon': _photoPinIds.contains(h.id)
              ? 'photo_${h.id}'
              : _iconFor(h.category, h.subcategory),
          'id': h.id,
          'kind': 'hotspot',
          'name': h.name,
        },
      });
    }
    for (final d in _filteredDeals) {
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [d.lng, d.lat],
        },
        'properties': {
          'icon': 'hotdeal',
          'id': d.id,
          'kind': 'deal',
          'name': d.businessName,
        },
      });
    }
    for (final r in _pickpockets) {
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [r.lng, r.lat],
        },
        'properties': {
          'icon': 'pickpocket',
          'id': r.id,
          'kind': 'pickpocket',
          'name': tr('pickpocket_activity'),
        },
      });
    }
    return jsonEncode({'type': 'FeatureCollection', 'features': features});
  }

  Future<void> _addSourceAndLayers(MapboxMap map) async {
    await map.style.addSource(GeoJsonSource(
      id: _srcId,
      data: _featureJson(),
      cluster: true,
      clusterRadius: 60,
      clusterMaxZoom: 16,
    ));

    // Cluster bubbles (yellow circle, dark border, size by count).
    await map.style.addLayer(CircleLayer(
      id: 'clusters',
      sourceId: _srcId,
      filter: ['has', 'point_count'],
      circleColor: PassimColors.brandArgb,
      circleStrokeColor: PassimColors.inkArgb,
      circleStrokeWidth: 3.0,
      circleRadiusExpression: [
        'step',
        ['get', 'point_count'],
        18.0,
        10,
        24.0,
        50,
        30.0,
      ],
    ));

    // Cluster count number.
    await map.style.addLayer(SymbolLayer(
      id: 'cluster-count',
      sourceId: _srcId,
      filter: ['has', 'point_count'],
      textFieldExpression: ['get', 'point_count_abbreviated'],
      textSize: 14.0,
      textColor: PassimColors.inkArgb,
      textIgnorePlacement: true,
      textAllowOverlap: true,
    ));

    // Individual places: category icon, with names fading in when zoomed in.
    // Mapbox auto-hides colliding labels (text-allow-overlap false), so names
    // never form a wall.
    await map.style.addLayer(SymbolLayer(
      id: 'unclustered',
      sourceId: _srcId,
      filter: [
        '!',
        ['has', 'point_count'],
      ],
      iconImageExpression: ['get', 'icon'],
      iconSize: 0.125,
      iconAllowOverlap: true,
      iconAnchor: IconAnchor.BOTTOM,
      textFieldExpression: ['get', 'name'],
      textSize: 12.0,
      textColor: 0xFFFFFFFF,
      textHaloColor: 0xFF000000,
      textHaloWidth: 1.5,
      textAnchor: TextAnchor.TOP,
      textOffset: [0.0, 1.2],
      textOptional: true,
      textOpacityExpression: [
        'interpolate',
        ['linear'],
        ['zoom'],
        15.0,
        0.0,
        15.6,
        1.0,
      ],
    ));
  }

  Future<void> _updateSource() async {
    final map = _map;
    if (map == null || !_setupDone) return;
    try {
      await map.style.setStyleSourceProperty(_srcId, 'data', _featureJson());
    } catch (_) {}
  }

  // Tap: cluster → zoom in; place → open it.
  void _onMapTap(MapContentGestureContext context) async {
    final map = _map;
    if (map == null) return;
    List<QueriedRenderedFeature?> result;
    try {
      result = await map.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenCoordinate(context.touchPosition),
        RenderedQueryOptions(
            layerIds: ['clusters', 'unclustered'], filter: null),
      );
    } catch (_) {
      return;
    }
    if (result.isEmpty) return;

    Map<Object?, Object?>? clusterProps;
    List<Object?>? clusterCoords;
    Map<Object?, Object?>? placeProps;

    for (final qf in result) {
      final feat = qf?.queriedFeature.feature;
      if (feat == null) continue;
      final props = feat['properties'];
      if (props is! Map) continue;
      if (props.containsKey('point_count')) {
        clusterProps ??= props;
        final geom = feat['geometry'];
        if (geom is Map) clusterCoords = geom['coordinates'] as List<Object?>?;
      } else {
        placeProps = props;
        break; // a real place under the finger wins
      }
    }

    if (placeProps != null) {
      final id = placeProps['id'] as String?;
      final kind = placeProps['kind'] as String?;
      if (id == null) return;
      if (kind == 'hotspot') {
        final h = widget.hotspots.where((x) => x.id == id).firstOrNull;
        if (h != null) _openHotspot(h);
      } else if (kind == 'deal') {
        final d = widget.deals.where((x) => x.id == id).firstOrNull;
        if (d != null) _openDeal(d);
      } else if (kind == 'pickpocket') {
        final r = _pickpockets.where((x) => x.id == id).firstOrNull;
        if (r != null) _showPickpocket(r);
      }
    } else if (clusterProps != null && clusterCoords != null) {
      final lng = (clusterCoords[0] as num).toDouble();
      final lat = (clusterCoords[1] as num).toDouble();
      final cs = await map.getCameraState();
      await map.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(lng, lat)),
          zoom: (cs.zoom + 2).clamp(1.0, 20.0),
        ),
        MapAnimationOptions(duration: 500),
      );
    }
  }

  void _showPickpocket(PickpocketReport r) {
    final d = DateTime.now().difference(r.createdAt);
    final ago = d.inMinutes < 1
        ? 'just now'
        : (d.inMinutes < 60 ? '${d.inMinutes} min ago' : '${d.inHours} h ago');
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
                          color: PassimColors.ink)),
                ),
                Text(ago,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              r.description?.isNotEmpty == true
                  ? r.description!
                  : 'No description provided.',
              style: const TextStyle(
                  fontSize: 15, height: 1.4, color: PassimColors.surface),
            ),
          ],
        ),
      ),
    );
  }

  void _openHotspot(Hotspot hotspot) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HotspotDetailScreen(
          hotspot: hotspot,
          audioService: widget.audioService,
          savedStore: widget.savedStore,
          entitlements: widget.entitlements,
          citypackId: widget.citypackId,
          cityName: widget.cityName,
          cityPriceCents: widget.cityPriceCents,
          repo: widget.repo,
          authService: widget.authService,
        ),
      ),
    );
  }

  void _openDeal(HotDeal deal) {
    final repo = widget.repo;
    if (repo == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DealDetailScreen(deal: deal, repo: repo),
    ));
  }

  void _toggleCategory(String c) {
    setState(() {
      _visibleCategories.contains(c)
          ? _visibleCategories.remove(c)
          : _visibleCategories.add(c);
    });
    _updateSource();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        // Compact bar — tap to reveal search + category filters (animated),
        // keeping the map as large as possible on small screens.
        GestureDetector(
          onTap: () => setState(() => _panelOpen = !_panelOpen),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: Row(
              children: [
                const Icon(Icons.tune, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _search.isNotEmpty
                        ? '"$_search"'
                        : _visibleCategories.length < _categoryMeta.length
                            ? tr('filters_active')
                            : tr('search_and_filters'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                if (_search.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      setState(() => _search = '');
                      _updateSource();
                    },
                    child: const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(Icons.close, size: 18, color: Colors.grey),
                    ),
                  ),
                AnimatedRotation(
                  turns: _panelOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.keyboard_arrow_down,
                      color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: !_panelOpen
              ? const SizedBox(width: double.infinity)
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Search places, landmarks, deals...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _search.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _search = '');
                                    _updateSource();
                                  },
                                )
                              : null,
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
                          _updateSource();
                        },
                      ),
                    ),
                    // Live matches — tap to fly to the place on the map.
                    if (_search.trim().isNotEmpty)
                      for (final h in _filtered.take(5))
                        ListTile(
                          dense: true,
                          leading:
                              CategoryBadge(category: h.category, size: 30),
                          title: Text(h.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                          onTap: () async {
                            _searchCtrl.clear();
                            setState(() {
                              _panelOpen = false;
                              _search = ''; // don't keep filtering the map
                            });
                            _updateSource();
                            FocusScope.of(context).unfocus();
                            await _map?.flyTo(
                              CameraOptions(
                                center: Point(
                                    coordinates: Position(h.lng, h.lat)),
                                zoom: 17,
                              ),
                              MapAnimationOptions(duration: 800),
                            );
                          },
                        ),
                    SizedBox(
                      height: 86,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        children: [
                          for (final entry in _categoryMeta.entries)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8),
                              child: GestureDetector(
                                onTap: () => _toggleCategory(entry.key),
                                child: AnimatedOpacity(
                                  duration:
                                      const Duration(milliseconds: 150),
                                  opacity: _visibleCategories
                                          .contains(entry.key)
                                      ? 1.0
                                      : 0.4,
                                  child: Column(
                                    children: [
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          AnimatedContainer(
                                            duration: Duration(
                                                milliseconds: 150),
                                            padding:
                                                const EdgeInsets.all(3),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: _visibleCategories
                                                        .contains(entry.key)
                                                    ? DykColors.yellow
                                                    : Colors.transparent,
                                                width: 2,
                                              ),
                                            ),
                                            child: CategoryBadge(
                                                category: entry.key,
                                                size: 52),
                                          ),
                                          if (_visibleCategories
                                              .contains(entry.key))
                                            Positioned(
                                              right: -2,
                                              top: -2,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(
                                                        1.5),
                                                decoration:
                                                    const BoxDecoration(
                                                  color: DykColors.yellow,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                    Icons.check,
                                                    size: 11,
                                                    color: Colors.white),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(entry.value.$2,
                                          style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight:
                                                  FontWeight.w700)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
        Expanded(
          child: Stack(
            children: [
              MapWidget(
                key: const ValueKey('nearby_map'),
                cameraOptions: CameraOptions(
                  center: Point(
                    coordinates: Position(_palmaCenterLng, _palmaCenterLat),
                  ),
                  zoom: 14.5,
                  pitch: 40, // tilted view so the 3D buildings read
                ),
                styleUri:
                    dark ? MapboxStyles.DARK : MapboxStyles.MAPBOX_STREETS,
                onMapCreated: _onMapCreated,
                onStyleLoadedListener: (_) => _setupMap(),
                onStyleImageMissingListener: _onStyleImageMissing,
                onTapListener: _onMapTap,
              ),
              // Pull-up list of the closest places (photo rows).
              DraggableScrollableSheet(
                initialChildSize: 0.10,
                minChildSize: 0.10,
                maxChildSize: 0.65,
                snap: true,
                builder: (context, ctrl) => Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? PassimColors.ink
                        : Colors.white,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20)),
                    boxShadow: const [
                      BoxShadow(color: Colors.black38, blurRadius: 10)
                    ],
                  ),
                  child: ListView(
                    controller: ctrl,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Text(tr('nearest_you'),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15)),
                          const SizedBox(width: 6),
                          Text(tr('within_steps'),
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      for (final (h, d) in _nearest) _nearbyRow(h, d),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 16,
                bottom: 96,
                child: FloatingActionButton(
                  heroTag: 'findMe',
                  backgroundColor: DykColors.yellow,
                  foregroundColor: DykColors.black,
                  onPressed: _centerOnUser,
                  child: const Icon(Icons.my_location),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _fmtMeters(double m) => m >= 2000
      ? '${(m / 1000).toStringAsFixed(1)} km'
      : '${StepStore.fmt(StepStore.stepsFromMeters(m))} ${tr('steps_unit')}';

  /// Hotspots visible under the current filters, sorted by distance to the
  /// user (alphabetical until there is a GPS fix).
  List<(Hotspot, double?)> get _nearest {
    final pos = _userPos;
    final rows = [
      for (final h in _filtered)
        (
          h,
          pos == null
              ? null
              : Geolocator.distanceBetween(
                  pos.latitude, pos.longitude, h.lat, h.lng)
        )
    ];
    rows.sort((a, b) => a.$2 == null || b.$2 == null
        ? a.$1.name.compareTo(b.$1.name)
        : a.$2!.compareTo(b.$2!));
    // Keep the list walkable: only places within ~500 steps (≈375 m).
    // Without a GPS fix we show the nearest few instead of everything.
    if (pos != null) {
      final within = rows.where((r) => (r.$2 ?? 0) <= 375).toList();
      return within.isNotEmpty ? within : rows.take(3).toList();
    }
    return rows.take(8).toList();
  }

  Widget _nearbyRow(Hotspot h, double? dist) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final img = h.images.isNotEmpty ? h.images.first : null;
    return GestureDetector(
      onTap: () => _openHotspot(h),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: dark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // Photo with a small category badge — icon-only fallback.
            SizedBox(
              width: 56,
              height: 56,
              child: img != null
                  ? Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: img,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Center(
                                child: CategoryBadge(
                                    category: h.category, size: 44)),
                          ),
                        ),
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: Container(
                            padding: const EdgeInsets.all(1.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: dark
                                      ? PassimColors.ink
                                      : Colors.white,
                                  width: 2),
                            ),
                            child:
                                CategoryBadge(category: h.category, size: 20),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: CategoryBadge(category: h.category, size: 44)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    '${tr('cat_${h.category}').toUpperCase()}${dist != null ? ' · ${_fmtMeters(dist)}' : ''}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: PassimColors.brand),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
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
        desiredAccuracy: LocationAccuracy.high,
      );
      await map.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(pos.longitude, pos.latitude)),
          zoom: 15.5,
        ),
        MapAnimationOptions(duration: 900),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('no_location'))),
        );
      }
    }
  }
}
