import 'package:flutter/material.dart';

import '../../models/hotspot.dart';
import '../../services/audio_service.dart';
import '../../services/auth_service.dart';
import '../../services/dyk_repository.dart';
import '../../services/entitlements.dart';
import '../../services/saved_store.dart';
import '../../models/tour.dart';
import '../hotspot_detail_screen.dart';
import '../tour_detail_screen.dart';
import '../../theme/dyk_theme.dart';
import '../../widgets/hotspot_list_tile.dart';
import '../../i18n/i18n.dart';

class SavedTab extends StatefulWidget {
  final SavedStore savedStore;
  final List<Hotspot> allHotspots;
  final AudioService audioService;
  final DykRepositoryBase? repo;
  final Entitlements? entitlements;
  final String? citypackId;
  final String? cityName;
  final int cityPriceCents;
  final AuthService? authService;

  /// Whether this is the selected tab. The shell keeps every tab alive in an
  /// IndexedStack, so initState runs once; the kept rounds are reloaded when
  /// this goes false to true.
  final bool isActive;

  const SavedTab({
    super.key,
    required this.savedStore,
    required this.allHotspots,
    required this.audioService,
    this.repo,
    this.entitlements,
    this.citypackId,
    this.cityName,
    this.cityPriceCents = 0,
    this.authService,
    this.isActive = true,
  });

  @override
  State<SavedTab> createState() => _SavedTabState();
}

class _SavedTabState extends State<SavedTab> {
  List<Tour> _rounds = [];

  @override
  void initState() {
    super.initState();
    _loadRounds();
  }

  @override
  void didUpdateWidget(SavedTab old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) _loadRounds();
  }

  Future<void> _loadRounds() async {
    final repo = widget.repo;
    final auth = widget.authService;
    if (repo == null || auth == null || !auth.isSignedIn) {
      if (_rounds.isNotEmpty) setState(() => _rounds = []);
      return;
    }
    final rounds = await repo.loadSavedTours();
    if (mounted) setState(() => _rounds = rounds);
  }

  Widget _roundsSection(
      BuildContext context, DykRepositoryBase repo, AuthService auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('saved_rounds'),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        for (final t in _rounds)
          Card(
            child: ListTile(
              leading: const Icon(Icons.route, color: DykColors.yellow),
              title: Text(t.title),
              subtitle: t.distanceMeters == null
                  ? null
                  : Text(
                      '${(t.distanceMeters! / 1000).toStringAsFixed(1)} km'
                      '${t.estMinutes == null ? '' : ' · ${t.estMinutes} min'}'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => TourDetailScreen(
                  tour: t,
                  repo: repo,
                  authService: auth,
                  audioService: widget.audioService,
                ),
              )),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final savedStore = widget.savedStore;
    final audioService = widget.audioService;
    final repo = widget.repo;
    final authService = widget.authService;
    final entitlements = widget.entitlements;
    final citypackId = widget.citypackId;
    final cityName = widget.cityName;
    final cityPriceCents = widget.cityPriceCents;
    return AnimatedBuilder(
      animation: savedStore,
      builder: (context, _) {
        final saved = widget.allHotspots
            .where((h) => savedStore.isSaved(h.id))
            .toList();
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const Icon(Icons.favorite, color: DykColors.yellow, size: 26),
                const SizedBox(width: 8),
                Text(tr('saved_title'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              ],
            ),
            const SizedBox(height: 4),
            Text(tr('saved_sub'),
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            if (_rounds.isNotEmpty && repo != null && authService != null)
              _roundsSection(context, repo, authService),
            // Rounds only: the rounds above are the content, so no empty note.
            if (saved.isEmpty && _rounds.isNotEmpty)
              const SizedBox.shrink()
            else if (saved.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    tr('saved_empty'),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              for (final h in saved)
                Dismissible(
                  key: ValueKey('saved_${h.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    alignment: Alignment.centerRight,
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      // Fixed red swipe-to-delete bg, not theme-derived.
                      children: const [
                        Icon(Icons.delete_outline,
                            color: PassimColors.onPhoto),
                        SizedBox(width: 8),
                        Text('REMOVE',
                            style: TextStyle(
                                color: PassimColors.onPhoto,
                                fontWeight: FontWeight.w900,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                  onDismissed: (_) => savedStore.toggle(h.id),
                  child: HotspotListTile(
                  hotspot: h,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HotspotDetailScreen(
                          hotspot: h,
                          audioService: audioService,
                          savedStore: savedStore,
                          entitlements: entitlements,
                          citypackId: citypackId,
                          cityName: cityName,
                          cityPriceCents: cityPriceCents,
                          repo: repo,
                          authService: authService,
                        ),
                      ),
                    );
                  },
                ),
                ),
          ],
        );
      },
    );
  }
}
