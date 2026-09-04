import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../models/city_pack.dart';
import '../models/hot_deal.dart';
import '../models/hotspot.dart';
import '../models/internal_ad.dart';
import '../models/tour.dart';
import '../services/auth_service.dart';
import '../services/app_state.dart';
import '../services/audio_service.dart';
import '../services/dyk_repository.dart';
import '../services/entitlements.dart';
import '../services/notification_log.dart';
import '../services/saved_store.dart';
import '../widgets/mini_player.dart';
import 'hotspot_detail_screen.dart';
import 'welcome_city_screen.dart';
import 'tabs/explore_tab.dart';
import 'tabs/more_tab.dart';
import 'tabs/nearby_tab.dart';
import 'tabs/profile_tab.dart';
import 'tabs/saved_tab.dart';
import 'tabs/tours_tab.dart';
import '../i18n/i18n.dart';
import '../theme/dyk_theme.dart';
import '../widgets/passim_background.dart';
import '../widgets/passim_nav_bar.dart';

class AppShell extends StatefulWidget {
  final AppState appState;
  final NotificationLog notificationLog;
  final SavedStore savedStore;
  final List<Hotspot> hotspots;
  final List<HotDeal> deals;
  final List<Tour> tours;
  final List<InternalAd> ads;
  final List<CityPack> cityPacks;
  final String activePackId;
  final AudioService audioService;
  final AuthService authService;
  final DykRepositoryBase repo;
  final Entitlements entitlements;
  final VoidCallback onToggleExploring;
  final void Function(CityPack) onDownloadPack;
  final VoidCallback onAuthChanged;
  final Future<void> Function()? onRefresh;

  const AppShell({
    super.key,
    required this.appState,
    required this.notificationLog,
    required this.savedStore,
    required this.hotspots,
    this.deals = const [],
    this.tours = const [],
    this.ads = const [],
    required this.cityPacks,
    required this.activePackId,
    required this.audioService,
    required this.authService,
    required this.repo,
    required this.entitlements,
    required this.onToggleExploring,
    required this.onDownloadPack,
    required this.onAuthChanged,
    this.onRefresh,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  String? _city;

  @override
  void initState() {
    super.initState();
    _detectCity();
  }

  // When the city changes (GPS or manual) to one the user hasn't unlocked,
  // greet them with the welcome / unlock screen.
  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activePackId != widget.activePackId &&
        !widget.entitlements.isCityUnlocked(widget.activePackId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showWelcome());
    }
  }

  void _showWelcome() {
    final pack = _activePack;
    if (pack == null || !mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => WelcomeCityScreen(
        cityName: pack.city,
        cityId: pack.id,
        priceCents: pack.priceCents,
        hotspotCount: widget.hotspots.length,
        entitlements: widget.entitlements,
        repo: widget.repo,
        authService: widget.authService,
      ),
    ));
  }

  // Wrap a tab in pull-to-refresh: dragging down re-fetches the active
  // city's content so admin changes show without restarting the app.
  Widget _refreshable(Widget child) {
    final onRefresh = widget.onRefresh;
    if (onRefresh == null) return child;
    return RefreshIndicator(
      color: PassimColors.brand,
      backgroundColor: PassimColors.ink,
      onRefresh: onRefresh,
      child: child,
    );
  }

  // The city pack currently loaded (published packs only reach the app).
  CityPack? get _activePack {
    for (final p in widget.cityPacks) {
      if (p.id == widget.activePackId) return p;
    }
    return null;
  }

  // Reverse-geocode the current GPS position and, if it matches a published
  // city, auto-switch the app to that city's content.
  Future<void> _detectCity() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low);
      final placemarks =
          await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isEmpty || !mounted) return;
      final p = placemarks.first;
      final detected = (p.locality?.isNotEmpty == true
              ? p.locality
              : (p.subAdministrativeArea?.isNotEmpty == true
                  ? p.subAdministrativeArea
                  : p.administrativeArea)) ??
          '';
      if (detected.isEmpty) return;
      setState(() => _city = detected.toUpperCase());

      // Auto-select the matching published city (by name), if any.
      final lower = detected.toLowerCase();
      for (final pack in widget.cityPacks) {
        final c = pack.city.toLowerCase();
        if ((lower.contains(c) || c.contains(lower)) &&
            pack.id != widget.activePackId) {
          widget.onDownloadPack(pack);
          break;
        }
      }
    } catch (_) {}
  }

  // Manual city switch — searchable, grouped by country.
  void _openCityPicker() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    var query = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: dark ? PassimColors.ink : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final q = query.trim().toLowerCase();
          final packs = widget.cityPacks
              .where((p) =>
                  q.isEmpty ||
                  p.city.toLowerCase().contains(q) ||
                  p.country.toLowerCase().contains(q))
              .toList();
          // Group by country, countries alphabetical, cities alphabetical.
          final byCountry = <String, List<CityPack>>{};
          for (final p in packs) {
            (byCountry[p.country] ??= []).add(p);
          }
          final countries = byCountry.keys.toList()..sort();
          for (final c in countries) {
            byCountry[c]!.sort((a, b) => a.city.compareTo(b.city));
          }
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 14),
                  Text(tr('choose_city'),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  if (widget.cityPacks.length > 5)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        autofocus: false,
                        onChanged: (v) => setSheet(() => query = v),
                        decoration: InputDecoration(
                          hintText: tr('search_city'),
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  if (widget.cityPacks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(tr('no_cities')),
                    )
                  else
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final country in countries) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 14, 16, 4),
                              child: Text(
                                '${byCountry[country]!.first.flag}  ${country.toUpperCase()}',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.1,
                                    color: PassimColors.brand),
                              ),
                            ),
                            for (final pack in byCountry[country]!)
                              ListTile(
                                leading: Icon(Icons.location_city,
                                    color: pack.id == widget.activePackId
                                        ? PassimColors.brand
                                        : null),
                                title: Text(pack.city,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                trailing: pack.id == widget.activePackId
                                    ? const Icon(Icons.check_circle,
                                        color: PassimColors.brand)
                                    : null,
                                onTap: () {
                                  Navigator.of(context).pop();
                                  if (pack.id != widget.activePackId) {
                                    widget.onDownloadPack(pack);
                                  }
                                },
                              ),
                          ],
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Profile is reached from the header avatar (top-right), not the bottom nav.
  void _openProfile() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        return Scaffold(
          appBar: AppBar(
            title: Text(tr('profile'),
                style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
          body: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/landing_background.jpg'),
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
            child: Container(
              decoration: dark
              ? passimScrim()
              : BoxDecoration(
                  color: PassimColors.sand.withValues(alpha: 0.85)),
              child: ProfileTab(
                savedStore: widget.savedStore,
                notificationLog: widget.notificationLog,
                authService: widget.authService,
                appState: widget.appState,
                repo: widget.repo,
                entitlements: widget.entitlements,
                citypackId: widget.activePackId,
                cityName: _activePack?.city,
                cityPriceCents: _activePack?.priceCents ?? 0,
                onToggleExploring: widget.onToggleExploring,
                onAuthChanged: () {
                  widget.onAuthChanged();
                  if (mounted) setState(() {});
                },
              ),
            ),
          ),
        );
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      // The glass bar blurs whatever is behind it — without this the blur
      // would have nothing to work with.
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 64,
        // The wordmark lives in flexibleSpace, not in `title`: AppBar refuses
        // to let a centred title overlap the leading slot, so with a 160 px
        // city pill the logo gets shoved right on narrow phones and sits
        // correctly on wide ones. This centres against the full width always.
        flexibleSpace: const SafeArea(
          bottom: false,
          child: SizedBox(
            height: 64,
            child: Center(child: PassimLogo(height: 34)),
          ),
        ),
        // Left: city location pill.
        leadingWidth: 160,
        leading: Builder(builder: (context) {
          final label = _activePack?.city.toUpperCase() ?? _city;
          if (label == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: _openCityPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: PassimColors.brand,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.place,
                          size: 14, color: PassimColors.ink),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: PassimColors.ink,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down,
                          size: 16, color: PassimColors.ink),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        // Right: profile avatar → opens the Profile screen.
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _openProfile,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: PassimColors.brand,
                backgroundImage: widget.authService.isSignedIn
                    ? AssetImage(widget.authService.avatarAsset)
                    : null,
                child: widget.authService.isSignedIn
                    ? null
                    : const Icon(Icons.person,
                        color: PassimColors.ink, size: 20),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/landing_background.jpg'),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        child: Container(
          // Scrim — artwork visible but clearly behind the content.
          decoration: dark
              ? passimScrim()
              : BoxDecoration(
                  color: PassimColors.sand.withValues(alpha: 0.85)),
          child: IndexedStack(
        index: _index,
        children: [
          _refreshable(ExploreTab(
            appState: widget.appState,
            notificationLog: widget.notificationLog,
            savedStore: widget.savedStore,
          )),
          NearbyTab(
            hotspots: widget.hotspots,
            deals: widget.deals,
            audioService: widget.audioService,
            savedStore: widget.savedStore,
            repo: widget.repo,
            entitlements: widget.entitlements,
            citypackId: widget.activePackId,
            cityName: _activePack?.city,
            cityPriceCents: _activePack?.priceCents ?? 0,
            authService: widget.authService,
          ),
          _refreshable(ToursTab(
            tours: widget.tours,
            repo: widget.repo,
            authService: widget.authService,
            audioService: widget.audioService,
            headerImage: _activePack?.headerImage,
            cityName: _activePack?.city,
          )),
          _refreshable(SavedTab(
            savedStore: widget.savedStore,
            allHotspots: widget.hotspots,
            audioService: widget.audioService,
            repo: widget.repo,
            entitlements: widget.entitlements,
            citypackId: widget.activePackId,
            cityName: _activePack?.city,
            cityPriceCents: _activePack?.priceCents ?? 0,
            authService: widget.authService,
          )),
          _refreshable(MoreTab(
            ads: widget.ads,
            repo: widget.repo,
            authService: widget.authService,
            entitlements: widget.entitlements,
            citypackId: widget.activePackId,
            cityName: _activePack?.city,
            cityPriceCents: _activePack?.priceCents ?? 0,
          )),
        ],
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MiniPlayer(
            audioService: widget.audioService,
            onOpenHotspot: _openHotspotById,
          ),
          PassimNavBar(
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
            items: [
              PassimNavItem(
                  Icons.map_outlined, Icons.map, tr('nav_explore')),
              PassimNavItem(Icons.location_on_outlined, Icons.location_on,
                  tr('nav_nearby')),
              PassimNavItem(Icons.route_outlined, Icons.route, tr('nav_tours')),
              PassimNavItem(
                  Icons.favorite_outline, Icons.favorite, tr('nav_saved')),
              PassimNavItem(
                  Icons.grid_view_outlined, Icons.grid_view, tr('nav_more')),
            ],
          ),
        ],
      ),
    );
  }

  // Mini player tap → jump back to the hotspot whose narration is playing.
  void _openHotspotById(String hotspotId) {
    final h = widget.hotspots.where((x) => x.id == hotspotId).firstOrNull;
    if (h == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => HotspotDetailScreen(
        hotspot: h,
        audioService: widget.audioService,
        savedStore: widget.savedStore,
        entitlements: widget.entitlements,
        citypackId: widget.activePackId,
        cityName: _activePack?.city,
        cityPriceCents: _activePack?.priceCents ?? 0,
        repo: widget.repo,
        authService: widget.authService,
      ),
    ));
  }
}
