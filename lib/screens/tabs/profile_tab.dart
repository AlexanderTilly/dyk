import 'package:flutter/material.dart';

import '../../services/app_state.dart';
import '../../services/auth_service.dart';
import '../../services/dyk_repository.dart';
import '../../services/entitlements.dart';
import '../../services/notification_log.dart';
import '../../services/saved_store.dart';
import '../../theme/dyk_theme.dart';
import '../auth_screen.dart';
import '../premium_screen.dart';
import '../settings_screen.dart';
import '../support_screen.dart';
import '../../i18n/i18n.dart';
import '../../services/step_store.dart';

class ProfileTab extends StatelessWidget {
  final SavedStore savedStore;
  final NotificationLog notificationLog;
  final AuthService authService;
  final AppState appState;
  final VoidCallback onToggleExploring;
  final VoidCallback onAuthChanged;
  final DykRepositoryBase? repo;
  final Entitlements? entitlements;
  final String? citypackId;
  final String? cityName;
  final int cityPriceCents;

  const ProfileTab({
    super.key,
    required this.savedStore,
    required this.notificationLog,
    required this.authService,
    required this.appState,
    required this.onToggleExploring,
    required this.onAuthChanged,
    this.repo,
    this.entitlements,
    this.citypackId,
    this.cityName,
    this.cityPriceCents = 0,
  });

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SettingsScreen(
        authService: authService,
        appState: appState,
        onToggleExploring: onToggleExploring,
        onAuthChanged: onAuthChanged,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final visited = notificationLog.entries
        .where((e) => e.type == 'hotspot')
        .length;
    final savedCount = savedStore.savedIds.length;

    Widget statCard(String value, String label) => Expanded(
          child: Column(
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900)),
              Text(label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        );

    Widget menuRow(IconData icon, String label, VoidCallback onTap) =>
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: dark ? Colors.white10 : Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: ListTile(
            leading: Icon(icon, color: Colors.amber.shade700),
            title: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right),
            onTap: onTap,
          ),
        );

    void openPremium() {
      final e = entitlements;
      final cityId = citypackId;
      final r = repo;
      if (e == null || cityId == null || r == null) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PremiumScreen(
          entitlements: e,
          repo: r,
          authService: authService,
          cityId: cityId,
          cityName: cityName ?? 'this city',
          cityPriceCents: cityPriceCents,
        ),
      ));
    }

    return AnimatedBuilder(
      animation: savedStore,
      builder: (context, _) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 40 + MediaQuery.of(context).padding.bottom),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: DykColors.yellow,
                  backgroundImage: authService.isSignedIn
                      ? AssetImage(authService.avatarAsset)
                      : null,
                  child: authService.isSignedIn
                      ? null
                      : const Text('🧭', style: TextStyle(fontSize: 36)),
                ),
                const SizedBox(height: 8),
                Text(authService.displayLabel,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900)),
                Text('"Collect moments, not things."',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Sign-in card for guests
          if (!authService.isSignedIn)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: DykColors.yellow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('guest_title'),
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: DykColors.black)),
                        Text(tr('guest_sub'),
                            style: TextStyle(
                                fontSize: 12, color: DykColors.black)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DykColors.black,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final ok = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) =>
                              AuthScreen(authService: authService),
                        ),
                      );
                      if (ok == true) onAuthChanged();
                    },
                    child: Text(tr('sign_in')),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: dark ? Colors.white10 : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                statCard('1', tr('cities_explored')),
                statCard('$visited', tr('hotspots_visited')),
                Expanded(
                  child: FutureBuilder<int>(
                    future: StepStore.todaySteps(),
                    builder: (context, snap) => Column(
                      children: [
                        Text(StepStore.fmt(snap.data ?? 0),
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w900)),
                        Text(tr('steps_today'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
                statCard('$savedCount', tr('saved_items')),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Exploring on/off — geofence notifications about nearby places.
          AnimatedBuilder(
            animation: appState,
            builder: (context, _) {
              final on = appState.isExploring;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: dark ? Colors.white10 : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(on ? Icons.explore : Icons.explore_off,
                        color: on ? Colors.amber.shade700 : Colors.grey),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('exploring'),
                              style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text(tr('exploring_sub'),
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    Switch(
                      value: on,
                      activeColor: DykColors.yellow,
                      onChanged: (_) => onToggleExploring(),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // Go Premium banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DykColors.yellow.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Text('👑', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('go_premium'),
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                      Text(tr('premium_pitch'),
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: openPremium,
                  child: Text(tr('view_plans')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          menuRow(Icons.person_outline, tr('edit_profile'), () => _openSettings(context)),
          menuRow(Icons.settings_outlined, tr('settings'), () => _openSettings(context)),
          menuRow(Icons.help_outline, tr('help_support'), () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SupportScreen(authService: authService),
            ));
          }),
          menuRow(Icons.info_outline, tr('about_app'), () {
            showAboutDialog(
              context: context,
              applicationName: 'Did You Know?',
              children: const [
                Text('Explore cities. Discover stories. Unlock hidden gems.'),
              ],
            );
          }),
          if (authService.isSignedIn)
            menuRow(Icons.logout, tr('sign_out'), () async {
              await authService.signOut();
              onAuthChanged();
            }),
        ],
      ),
    );
  }
}
