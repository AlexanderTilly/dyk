import 'package:flutter/material.dart';

import '../../models/hotspot.dart';
import '../../services/audio_service.dart';
import '../../services/saved_store.dart';
import '../hotspot_detail_screen.dart';
import '../../widgets/hotspot_list_tile.dart';

class SavedTab extends StatelessWidget {
  final SavedStore savedStore;
  final List<Hotspot> allHotspots;
  final AudioService audioService;

  const SavedTab({
    super.key,
    required this.savedStore,
    required this.allHotspots,
    required this.audioService,
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
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const Text('❤️ ', style: TextStyle(fontSize: 24)),
                Text('SAVED',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Your saved places — all in one place.',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            if (saved.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'Nothing saved yet — tap the bookmark on any place to save it here.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              for (final h in saved)
                HotspotListTile(
                  hotspot: h,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HotspotDetailScreen(
                          hotspot: h,
                          audioService: audioService,
                        ),
                      ),
                    );
                  },
                ),
          ],
        );
      },
    );
  }
}
