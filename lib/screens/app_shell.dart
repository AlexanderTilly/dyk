import 'package:flutter/material.dart';

import '../models/city_pack.dart';
import '../models/hotspot.dart';
import '../services/app_state.dart';
import '../services/audio_service.dart';
import '../services/notification_log.dart';
import '../services/saved_store.dart';
import 'tabs/city_packs_tab.dart';
import 'tabs/explore_tab.dart';
import 'tabs/nearby_tab.dart';
import 'tabs/profile_tab.dart';
import 'tabs/saved_tab.dart';

class AppShell extends StatefulWidget {
  final AppState appState;
  final NotificationLog notificationLog;
  final SavedStore savedStore;
  final List<Hotspot> hotspots;
  final List<CityPack> cityPacks;
  final String activePackId;
  final AudioService audioService;
  final VoidCallback onToggleExploring;
  final void Function(CityPack) onDownloadPack;

  const AppShell({
    super.key,
    required this.appState,
    required this.notificationLog,
    required this.savedStore,
    required this.hotspots,
    required this.cityPacks,
    required this.activePackId,
    required this.audioService,
    required this.onToggleExploring,
    required this.onDownloadPack,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 64,
        title: Image.asset(
          'assets/images/dyk_logo.png',
          height: 56,
          fit: BoxFit.contain,
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/landing_background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          // Heavy scrim — the artwork should only be subtly visible
          // behind the content, unlike on onboarding.
          color: dark
              ? Colors.black.withValues(alpha: 0.86)
              : const Color(0xFFFAF6EE).withValues(alpha: 0.92),
          child: IndexedStack(
        index: _index,
        children: [
          ExploreTab(
            appState: widget.appState,
            notificationLog: widget.notificationLog,
            onToggleExploring: widget.onToggleExploring,
          ),
          NearbyTab(
            hotspots: widget.hotspots,
            audioService: widget.audioService,
          ),
          CityPacksTab(
            packs: widget.cityPacks,
            activePackId: widget.activePackId,
            onDownload: widget.onDownloadPack,
          ),
          SavedTab(
            savedStore: widget.savedStore,
            allHotspots: widget.hotspots,
            audioService: widget.audioService,
          ),
          ProfileTab(
            savedStore: widget.savedStore,
            notificationLog: widget.notificationLog,
          ),
        ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.amber.shade700,
        unselectedItemColor: dark ? Colors.white54 : Colors.black45,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'EXPLORE'),
          BottomNavigationBarItem(icon: Icon(Icons.location_on_outlined), label: 'NEARBY'),
          BottomNavigationBarItem(icon: Icon(Icons.location_city_outlined), label: 'CITY PACKS'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite_outline), label: 'SAVED'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'PROFILE'),
        ],
      ),
    );
  }
}
