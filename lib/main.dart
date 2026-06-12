import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/city_pack.dart';
import 'models/hot_deal.dart';
import 'models/hotspot.dart';
import 'screens/app_shell.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'services/app_state.dart';
import 'services/audio_service.dart';
import 'services/content_repository.dart';
import 'services/dyk_repository.dart';
import 'services/geo_fencing_service.dart';
import 'services/notification_log.dart';
import 'services/notification_service.dart';
import 'services/saved_store.dart';
import 'theme/dyk_theme.dart';

const _palmaCitypackId = 'a1b2c3d4-0000-0000-0000-000000000001';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://jqykkyhoxpykhixwgwyw.supabase.co',
    anonKey: 'sb_publishable_HCRDnKdePmnT0ukTyVlFCg_q0MRPyhK',
  );

  final prefs = await SharedPreferences.getInstance();
  final appState = AppState(prefs);
  final notificationLog = NotificationLog(prefs);
  final savedStore = SavedStore(prefs);

  final notificationService = NotificationService();
  await notificationService.initialize();

  // Load content from Supabase; fall back to bundled JSON when offline.
  final dykRepo = DykRepository();
  final cityPacks = await dykRepo.loadCityPacks();
  var hotspots = await dykRepo.loadHotspots(_palmaCitypackId);
  if (hotspots.isEmpty) {
    hotspots = await ContentRepository().loadHotspots();
  }
  final deals = await dykRepo.loadDeals(_palmaCitypackId);

  final audioService = AudioService();
  final geoService = GeoFencingService();

  runApp(DykApp(
    appState: appState,
    notificationLog: notificationLog,
    savedStore: savedStore,
    dykRepo: dykRepo,
    cityPacks: cityPacks,
    hotspots: hotspots,
    deals: deals,
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
    required this.audioService,
    required this.geoService,
    required this.notificationService,
  });

  @override
  State<DykApp> createState() => _DykAppState();
}

class _DykAppState extends State<DykApp> {
  final _navKey = GlobalKey<NavigatorState>();
  bool _listenersAttached = false;
  late List<Hotspot> _hotspots = widget.hotspots;
  late List<HotDeal> _deals = widget.deals;
  String _activePackId = _palmaCitypackId;

  void _attachListeners() {
    if (_listenersAttached) return;
    _listenersAttached = true;

    widget.geoService.onHotspotEnter.listen((hotspot) {
      if (!widget.appState.isExploring) return;
      if (!widget.appState.interests.contains(hotspot.category)) return;
      widget.notificationService.showHotspotNotification(
        hotspotId: hotspot.id,
        name: hotspot.name,
        year: hotspot.year,
      );
      widget.audioService.play(hotspot.audioFile);
      widget.notificationLog.add(LoggedNotification(
        type: 'hotspot',
        title: hotspot.name,
        body: hotspot.subtitle,
        category: hotspot.category,
        at: DateTime.now(),
      ));
    });

    widget.geoService.onDealEnter.listen((deal) {
      if (!widget.appState.isExploring) return;
      if (!widget.appState.interests.contains('hotdeal')) return;
      widget.notificationService.showDealNotification(
        dealId: deal.id,
        businessName: deal.businessName,
        offerText: deal.offerText,
        redeemCode: deal.redeemCode,
      );
      widget.notificationLog.add(LoggedNotification(
        type: 'deal',
        title: deal.businessName,
        body: deal.offerText,
        redeemCode: deal.redeemCode,
        at: DateTime.now(),
      ));
    });
  }

  // Must run AFTER location permission is granted, otherwise the
  // geofencing plugin fails silently and never recovers.
  Future<void> _startGeoMonitoring() async {
    _attachListeners();
    await widget.appState.setExploring(true);
    await widget.geoService.startMonitoring(_hotspots, deals: _deals);
  }

  Future<void> _toggleExploring() async {
    if (widget.appState.isExploring) {
      await widget.appState.setExploring(false);
      await widget.geoService.stop();
    } else {
      await _startGeoMonitoring();
    }
  }

  Future<void> _downloadPack(CityPack pack) async {
    final hotspots = await widget.dykRepo.loadHotspots(pack.id);
    final deals = await widget.dykRepo.loadDeals(pack.id);
    setState(() {
      _hotspots = hotspots;
      _deals = deals;
      _activePackId = pack.id;
    });
    if (widget.appState.isExploring) {
      await widget.geoService.stop();
      await widget.geoService.startMonitoring(hotspots, deals: deals);
    }
  }

  void _finishOnboarding() {
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
        cityPacks: widget.cityPacks,
        activePackId: _activePackId,
        audioService: widget.audioService,
        onToggleExploring: _toggleExploring,
        onDownloadPack: _downloadPack,
      );

  @override
  void dispose() {
    widget.audioService.dispose();
    widget.geoService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget home;
    if (widget.appState.onboardingDone) {
      // Returning user: resume exploring if it was on.
      if (widget.appState.isExploring) _startGeoMonitoring();
      home = _buildShell();
    } else {
      home = WelcomeScreen(
        onFinished: _finishOnboarding,
        onInterestsChosen: (interests) =>
            widget.appState.setInterests(interests),
      );
    }

    return MaterialApp(
      navigatorKey: _navKey,
      title: 'Did You Know?',
      debugShowCheckedModeBanner: false,
      theme: dykLightTheme(),
      darkTheme: dykDarkTheme(),
      home: home,
    );
  }
}
