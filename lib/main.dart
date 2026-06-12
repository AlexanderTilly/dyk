import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/hot_deal.dart';
import 'models/hotspot.dart';
import 'screens/map_screen.dart';
import 'screens/onboarding/interests_screen.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'services/app_state.dart';
import 'services/audio_service.dart';
import 'services/content_repository.dart';
import 'services/dyk_repository.dart';
import 'services/geo_fencing_service.dart';
import 'services/notification_service.dart';
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

  final notificationService = NotificationService();
  await notificationService.initialize();

  // Load content from Supabase; fall back to bundled JSON when offline.
  final dykRepo = DykRepository();
  var hotspots = await dykRepo.loadHotspots(_palmaCitypackId);
  if (hotspots.isEmpty) {
    hotspots = await ContentRepository().loadHotspots();
  }
  final deals = await dykRepo.loadDeals(_palmaCitypackId);

  final audioService = AudioService();
  final geoService = GeoFencingService();

  runApp(DykApp(
    appState: appState,
    hotspots: hotspots,
    deals: deals,
    audioService: audioService,
    geoService: geoService,
    notificationService: notificationService,
  ));
}

class DykApp extends StatefulWidget {
  final AppState appState;
  final List<Hotspot> hotspots;
  final List<HotDeal> deals;
  final AudioService audioService;
  final GeoFencingService geoService;
  final NotificationService notificationService;

  const DykApp({
    super.key,
    required this.appState,
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
  bool _listenersAttached = false;

  // Must run AFTER location permission is granted, otherwise the
  // geofencing plugin fails silently and never recovers.
  Future<void> _startGeoMonitoring() async {
    if (!_listenersAttached) {
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
      });
    }

    await widget.appState.setExploring(true);
    await widget.geoService
        .startMonitoring(widget.hotspots, deals: widget.deals);
  }

  @override
  void dispose() {
    widget.audioService.dispose();
    widget.geoService.dispose();
    super.dispose();
  }

  final _navKey = GlobalKey<NavigatorState>();

  void _finishOnboarding() {
    widget.appState.completeOnboarding();
    _startGeoMonitoring();
    _navKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => MapScreen(
          hotspots: widget.hotspots,
          audioService: widget.audioService,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget home;
    if (widget.appState.onboardingDone) {
      // Returning user: resume exploring if it was on.
      if (widget.appState.isExploring) _startGeoMonitoring();
      home = MapScreen(
        hotspots: widget.hotspots,
        audioService: widget.audioService,
      );
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
