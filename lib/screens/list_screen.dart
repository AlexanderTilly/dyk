import 'package:flutter/material.dart';
import '../models/hotspot.dart';
import '../services/audio_service.dart';
import '../widgets/hotspot_list_tile.dart';
import 'hotspot_detail_screen.dart';

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
        title: const Text('All locations'),
        backgroundColor: const Color(0xFFF97316),
        foregroundColor: Colors.white,
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
