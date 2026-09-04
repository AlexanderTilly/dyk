import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
// Prefixed: mapbox_maps_flutter also exports a `Position`.
import 'package:geolocator/geolocator.dart' as geo;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'i18n/i18n.dart';
import 'models/city_pack.dart';
import 'models/hot_deal.dart';
import 'models/hotspot.dart';
import 'models/internal_ad.dart';
import 'models/tour.dart';
import 'screens/app_shell.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'services/app_state.dart';
import 'services/audio_service.dart';
import 'services/content_repository.dart';
import 'services/auth_service.dart';
import 'services/device_profile_service.dart';
import 'services/dyk_repository.dart';
import 'services/entitlements.dart';
import 'services/geo_fencing_service.dart';
import 'services/geofence_foreground_service.dart';
import 'services/ios_geo_service.dart';
import 'services/proximity_engine.dart';
import 'services/step_store.dart';
import 'services/notification_router.dart';
import 'services/onboarding_music.dart';
import 'screens/deal_detail_screen.dart';
import 'screens/hotspot_detail_screen.dart';
import 'screens/paused_screen.dart';
import 'screens/splash_screen.dart';
import 'services/notification_log.dart';
import 'services/notification_service.dart';
import 'services/saved_store.dart';
import 'theme/dyk_theme.dart';

const _palmaCitypackId = 'a1b2c3d4-0000-0000-0000-000000000001';

const _mapboxToken =
    'pk.eyJ1IjoibGl0dGxld2h5IiwiYSI6ImNtZHJnMjc2bzBoM2EybHNmMWtpNW4xd24ifQ.NMHAZQhN_eP_3wxFUfNhdw';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Narration keeps playing when the app is backgrounded, with play/pause
  // controls on the lock screen and in the notification shade.
  await JustAudioBackground.init(
    androidNotificationChannelId: 'app.passim.audio',
    androidNotificationChannelName: 'Narration playback',
    androidNotificationOngoing: true,
  );

  // Required for the background geofencing service to talk to the UI isolate.
  FlutterForegroundTask.initCommunicationPort();

  // mapbox_maps_flutter reads the token from here, not AndroidManifest.
  MapboxOptions.setAccessToken(_mapboxToken);

  await Supabase.initialize(
    url: 'https://jqykkyhoxpykhixwgwyw.supabase.co',
    anonKey: 'sb_publishable_HCRDnKdePmnT0ukTyVlFCg_q0MRPyhK',
  );

  final prefs = await SharedPreferences.getInstance();
  await I18n.instance.load(prefs);
  final appState = AppState(prefs);
  final notificationLog = NotificationLog(prefs);
  final savedStore = SavedStore(prefs);

  final notificationService = NotificationService();
  await notificationService.initialize();

  // Load content from Supabase; fall back to bundled JSON when offline.
  final dykRepo = DykRepository();
  final cityPacks = await dykRepo.loadCityPacks();

  // Hand the published cities (with coordinates) to the background isolate so
  // it can greet the user when they arrive in a new city — even if the app is
  // closed. Only cities with a center + a price are candidates.
  await prefs.setString(
    'fg_cities',
    jsonEncode([
      for (final c in cityPacks)
        if (c.lat != null && c.lng != null)
          {
            'id': c.id,
            'city': c.city,
            'lat': c.lat,
            'lng': c.lng,
            'radius_km': c.welcomeRadiusKm,
            'price_cents': c.priceCents,
          }
    ]),
  );
  // Don't greet the city the app opened in — only genuinely new arrivals.
  if (prefs.getString('fg_last_city') == null) {
    await prefs.setString('fg_last_city', _palmaCitypackId);
  }
  var hotspots = await dykRepo.loadHotspots(_palmaCitypackId);
  if (hotspots.isEmpty) {
    hotspots = await ContentRepository().loadHotspots();
  }
  final deals = await dykRepo.loadDeals(_palmaCitypackId);
  final ads = await dykRepo.loadAds();
  final tours = await dykRepo.loadTours(_palmaCitypackId);

  final audioService = AudioService();
  final geoService = GeoFencingService();

  runApp(DykApp(
    appState: appState,
    ads: ads,
    notificationLog: notificationLog,
    savedStore: savedStore,
    dykRepo: dykRepo,
    cityPacks: cityPacks,
    hotspots: hotspots,
    deals: deals,
    tours: tours,
    audioService: audioService,
    geoService: geoService,
    notificationService: notificationService,
  ));
}

class DykApp extends StatefulWidget {
  final AppState appState;
  final NotificationLog notificationLog;
  final SavedStore savedStore;
  final DykRepositoryBase dykRepo;
  final List<CityPack> cityPacks;
  final List<Hotspot> hotspots;
  final List<HotDeal> deals;
  final List<InternalAd> ads;
  final List<Tour> tours;
  final AudioService audioService;
  final GeoFencingService geoService;
  final NotificationService notificationService;

  const DykApp({
    super.key,
    required this.appState,
    required this.notificationLog,
    required this.savedStore,
    required this.dykRepo,
    required this.cityPacks,
    required this.hotspots,
    required this.deals,
    this.ads = const [],
    this.tours = const [],
    required this.audioService,
    required this.geoService,
    required this.notificationService,
  });

  @override
  State<DykApp> createState() => _DykAppState();
}

class _DykAppState extends State<DykApp> {
  final _navKey = GlobalKey<NavigatorState>();
  final _fgService = GeofenceForegroundService();
  // iOS cannot run the Android-style foreground service; this replaces it.
  late final IosGeoService _iosGeo =
      IosGeoService(onPosition: _onPreciseFix);
  final _proximity = ProximityEngine();
  geo.Position? _lastFix;
  final _authService = AuthService();
  final _deviceService = DeviceProfileService();
  final _entitlements = Entitlements();
  bool _paused = false;
  bool _booting = true;
  late List<Hotspot> _hotspots = widget.hotspots;
  late List<HotDeal> _deals = widget.deals;
  late List<Tour> _tours = widget.tours;
  String _activePackId = _palmaCitypackId;

  @override
  void initState() {
    super.initState();
    // Route to a hotspot/deal when its notification is tapped.
    NotificationRouter.pending.addListener(_handleNotificationTap);
    // Handle a payload that arrived during cold start.
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleNotificationTap());
    _initTelemetry();
    _startForegroundPresence();
    // Language switch → re-fetch content so translations apply immediately.
    I18n.instance.addListener(_onLanguageChanged);
    // Branded splash for a moment on launch.
    Future.delayed(const Duration(milliseconds: 1900), () {
      if (mounted) setState(() => _booting = false);
    });
  }

  // Record anonymous install, sync the signed-in user's device info, and
  // check whether the account has been paused by an admin.
  Future<void> _initTelemetry() async {
    await _deviceService.recordInstall();
    await _entitlements.load(widget.dykRepo);
    if (_authService.isSignedIn) {
      await _deviceService.syncProfile();
      final paused = await _deviceService.isPaused();
      if (paused && mounted) setState(() => _paused = true);
    }
  }

  void _handleNotificationTap() {
    final payload = NotificationRouter.pending.value;
    if (payload == null) return;
    NotificationRouter.pending.value = null;

    final parts = payload.split(':');
    if (parts.length != 2) return;
    final type = parts[0];
    final id = parts[1];

    final nav = _navKey.currentState;
    if (nav == null) return;

    if (type == 'hotspot') {
      final h = _hotspots.where((x) => x.id == id).firstOrNull;
      if (h != null) {
        nav.push(MaterialPageRoute(
          builder: (_) => HotspotDetailScreen(
            hotspot: h,
            audioService: widget.audioService,
            savedStore: widget.savedStore,
            autoPlay: true,
            entitlements: _entitlements,
            citypackId: _activePackId,
            repo: widget.dykRepo,
            authService: _authService,
          ),
        ));
      }
    } else if (type == 'deal') {
      final d = _deals.where((x) => x.id == id).firstOrNull;
      if (d != null) {
        nav.push(MaterialPageRoute(
          builder: (_) => DealDetailScreen(deal: d, repo: widget.dykRepo),
        ));
      }
    } else if (type == 'city') {
      // "Welcome to <city>" push — switch the app to that city, which makes
      // AppShell greet the user with the welcome / unlock screen.
      final pack = widget.cityPacks.where((p) => p.id == id).firstOrNull;
      if (pack != null && pack.id != _activePackId) _downloadPack(pack);
    }
  }

  // Starts the background geofencing service (runs in foreground + background).
  // Must run AFTER location permission is granted.
  Future<void> _startGeoMonitoring() async {
    // Persist who we are so the background isolate can report presence.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('presence_label', _authService.displayLabel);
    final user = _authService.currentUser;
    if (user != null) {
      await prefs.setString('presence_user_id', user.id);
    } else {
      await prefs.remove('presence_user_id');
    }

    await widget.appState.setExploring(true);
    if (Platform.isIOS) {
      await _iosGeo.start(_hotspots);
    } else {
      await _fgService.start(
        hotspots: _hotspots,
        deals: _deals,
        interests: widget.appState.interests,
      );
    }
  }

  // Every precise fix while the user is inside a content zone. Proximity
  // checks and notifications land here next; for now it keeps the live map
  // fed, which also makes the zone switching observable in the field.
  DateTime _lastPresence = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _onPreciseFix(geo.Position pos) async {
    // Steps explored: the same GPS-delta model the Android isolate uses, with
    // the same sanity window so a bus ride is not counted as walking. The
    // tour screen counts its own, so skip while one is running.
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final tourActive = prefs.getBool('tour_active') ?? false;
    final last = _lastFix;
    if (last != null && !tourActive) {
      final moved = geo.Geolocator.distanceBetween(
          last.latitude, last.longitude, pos.latitude, pos.longitude);
      if (moved >= 3 && moved <= 300) await StepStore.addMeters(moved);
    }
    _lastFix = pos;

    if (DateTime.now().difference(_lastPresence).inSeconds >= 30) {
      _lastPresence = DateTime.now();
      unawaited(_reportPresenceAt(pos));
    }

    final arrivedMs = prefs.getInt('city_arrived_at');
    final hits = _proximity.check(
      lat: pos.latitude,
      lng: pos.longitude,
      hotspots: _hotspots,
      deals: _deals,
      interests: widget.appState.interests,
      tourActive: tourActive,
      stepsToday: await StepStore.todaySteps(),
      cityArrivedAt: arrivedMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(arrivedMs),
    );

    for (final hit in hits) {
      if (hit.kind == 'hotspot') {
        final h = _hotspots.where((x) => x.id == hit.id).firstOrNull;
        if (h != null) await _notifyHotspot(h);
      } else {
        final d = _deals.where((x) => x.id == hit.id).firstOrNull;
        if (d != null) await _notifyDeal(d, prefs.getString('anon_install_id'));
      }
    }
  }

  Future<void> _notifyHotspot(Hotspot h) async {
    await widget.notificationService.showHotspotNotification(
      hotspotId: h.id,
      name: h.name,
      year: int.tryParse(h.year) ?? 0,
      title: '${tr('now_at')} ${h.name}',
      body: tr('tap_story'),
    );
    await widget.notificationLog.add(LoggedNotification(
      type: 'hotspot',
      title: '${tr('now_at')} ${h.name}',
      body: tr('tap_story'),
      category: h.category,
      targetId: h.id,
      imageUrl: h.images.isNotEmpty ? h.images.first : null,
      at: DateTime.now(),
    ));
  }

  Future<void> _notifyDeal(HotDeal d, String? userKey) async {
    await widget.notificationService.showDealNotification(
      dealId: d.id,
      businessName: d.businessName,
      offerText: d.offerText,
      redeemCode: d.redeemCode,
    );
    await widget.notificationLog.add(LoggedNotification(
      type: 'deal',
      title: '🔥 ${d.businessName}',
      body: d.offerText,
      category: 'hotdeal',
      redeemCode: d.redeemCode,
      targetId: d.id,
      at: DateTime.now(),
    ));
    // Billable reach — the server dedupes per person, per deal, per day.
    if (userKey != null) {
      try {
        await Supabase.instance.client.rpc('deal_reach_log',
            params: {'p_deal_id': d.id, 'p_user_key': userKey});
      } catch (_) {}
    }
  }

  Future<void> _toggleExploring() async {
    if (widget.appState.isExploring) {
      await widget.appState.setExploring(false);
      await _fgService.stop();
      await _iosGeo.stop();
      await _endPresence();
    } else {
      await _startGeoMonitoring();
    }
  }

  // Live presence while the app is open. The background isolate also reports,
  // but only on Android — on iOS it barely runs, so without this an iPhone
  // never appears on the admin live map.
  Timer? _presenceTimer;

  void _startForegroundPresence() {
    _reportPresenceNow();
    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(
        const Duration(seconds: 30), (_) => _reportPresenceNow());
  }

  Future<void> _reportPresenceNow() async {
    if (!widget.appState.isExploring) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionId = prefs.getString('anon_install_id');
      if (sessionId == null) return;
      final pos = await geo.Geolocator.getCurrentPosition(
          desiredAccuracy: geo.LocationAccuracy.high);
      await _reportPresenceAt(pos);
    } catch (_) {
      // Presence is best-effort; never disturb the user over it.
    }
  }

  Future<void> _reportPresenceAt(geo.Position pos) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionId = prefs.getString('anon_install_id');
      if (sessionId == null) return;
      final n = DateTime.now();
      final steps =
          (prefs.getDouble('steps_day_m_${n.year}-${n.month}-${n.day}') ?? 0) /
              0.75;
      await Supabase.instance.client.rpc('record_presence', params: {
        'p_session_id': sessionId,
        'p_user_id': _authService.currentUser?.id,
        'p_label': _authService.displayLabel,
        'p_is_user': _authService.isSignedIn,
        'p_lat': pos.latitude,
        'p_lng': pos.longitude,
        'p_status': 'exploring',
        'p_status_detail': null,
        'p_steps': steps.round(),
      });
    } catch (_) {
      // Presence is best-effort; never disturb the user over it.
    }
  }

  // Remove our live dot when exploring stops.
  Future<void> _endPresence() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionId = prefs.getString('anon_install_id');
      if (sessionId != null) {
        await Supabase.instance.client
            .rpc('end_presence', params: {'p_session_id': sessionId});
      }
    } catch (_) {}
  }

  Future<void> _downloadPack(CityPack pack) async {
    final hotspots = await widget.dykRepo.loadHotspots(pack.id);
    final deals = await widget.dykRepo.loadDeals(pack.id);
    final tours = await widget.dykRepo.loadTours(pack.id);
    setState(() {
      _hotspots = hotspots;
      _deals = deals;
      _tours = tours;
      _activePackId = pack.id;
    });
    if (widget.appState.isExploring) {
      await _fgService.update(
        hotspots: hotspots,
        deals: deals,
        interests: widget.appState.interests,
      );
    }
  }

  void _onLanguageChanged() {
    _refreshContent();
  }

  // Pull-to-refresh: re-fetch the active city's content from Supabase so
  // admin changes show up without restarting the app.
  Future<void> _refreshContent() async {
    final pack =
        widget.cityPacks.where((p) => p.id == _activePackId).firstOrNull;
    if (pack != null) await _downloadPack(pack);
  }

  void _finishOnboarding() {
    OnboardingMusic.stop();
    widget.appState.completeOnboarding();
    _startGeoMonitoring();
    _navKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => _buildShell()),
      (route) => false,
    );
  }

  Widget _buildShell() => AppShell(
        appState: widget.appState,
        notificationLog: widget.notificationLog,
        savedStore: widget.savedStore,
        hotspots: _hotspots,
        deals: _deals,
        tours: _tours,
        ads: widget.ads,
        cityPacks: widget.cityPacks,
        activePackId: _activePackId,
        audioService: widget.audioService,
        authService: _authService,
        repo: widget.dykRepo,
        entitlements: _entitlements,
        onToggleExploring: _toggleExploring,
        onDownloadPack: _downloadPack,
        onRefresh: _refreshContent,
        onAuthChanged: () {
          _entitlements.load(widget.dykRepo);
          setState(() {});
        },
      );

  @override
  void dispose() {
    _presenceTimer?.cancel();
    I18n.instance.removeListener(_onLanguageChanged);
    widget.audioService.dispose();
    widget.geoService.dispose();
    super.dispose();
  }

  Widget _buildHome() {
    if (_booting) return const SplashScreen();
    if (_paused) {
      return PausedScreen(
        authService: _authService,
        onSignedOut: () => setState(() => _paused = false),
      );
    }
    if (widget.appState.onboardingDone) {
      // Returning user: resume exploring if it was on.
      if (widget.appState.isExploring) _startGeoMonitoring();
      return _buildShell();
    }
    return WelcomeScreen(
      onFinished: _finishOnboarding,
      onInterestsChosen: (interests) =>
          widget.appState.setInterests(interests),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild the whole app when the language changes (home is created
    // inside the builder so every screen picks up the new strings).
    return AnimatedBuilder(
      animation: I18n.instance,
      builder: (context, _) => MaterialApp(
        navigatorKey: _navKey,
        title: 'Did You Know?',
        debugShowCheckedModeBanner: false,
        theme: dykLightTheme(),
        darkTheme: dykDarkTheme(),
        builder: (context, child) =>
            WithForegroundTask(child: child ?? const SizedBox.shrink()),
        home: _buildHome(),
      ),
    );
  }
}
