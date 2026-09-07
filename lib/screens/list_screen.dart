import 'package:flutter/material.dart';
import '../i18n/i18n.dart';
import '../models/hotspot.dart';
import '../services/audio_service.dart';
import '../widgets/hotspot_list_tile.dart';
import 'hotspot_detail_screen.dart';
import '../theme/dyk_theme.dart';

class ListScreen extends StatelessWidget {
  final List<Hotspot> hotspots;
  final AudioService audioService;

  const ListScreen({
    super.key,
    required this.hotspots,
    required this.audioService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      appBar: AppBar(
        title: Text(tr('all_locations')),
        backgroundColor: const Color(0xFFF97316),
        // AppBar bg is a fixed orange, not theme-derived.
        foregroundColor: PassimColors.onPhoto,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: hotspots.length,
        itemBuilder: (_, i) => HotspotListTile(
          hotspot: hotspots[i],
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => HotspotDetailScreen(
                  hotspot: hotspots[i],
                  audioService: audioService,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
