import 'package:flutter/material.dart';

import '../../models/hotspot.dart';
import '../../services/audio_service.dart';
import '../../services/auth_service.dart';
import '../../services/dyk_repository.dart';
import '../../services/entitlements.dart';
import '../../services/saved_store.dart';
import '../hotspot_detail_screen.dart';
import '../../theme/dyk_theme.dart';
import '../../widgets/hotspot_list_tile.dart';
import '../../i18n/i18n.dart';

class SavedTab extends StatelessWidget {
  final SavedStore savedStore;
  final List<Hotspot> allHotspots;
  final AudioService audioService;
  final DykRepositoryBase? repo;
  final Entitlements? entitlements;
  final String? citypackId;
  final String? cityName;
  final int cityPriceCents;
  final AuthService? authService;

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
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: savedStore,
      builder: (context, _) {
        final saved = allHotspots
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
            if (saved.isEmpty)
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
                      children: const [
                        Icon(Icons.delete_outline, color: Colors.white),
                        SizedBox(width: 8),
                        Text('REMOVE',
                            style: TextStyle(
                                color: Colors.white,
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
