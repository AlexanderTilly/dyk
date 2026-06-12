import 'package:flutter/material.dart';
import '../models/hotspot.dart';
import '../services/audio_service.dart';
import '../widgets/audio_player_widget.dart';

class HotspotDetailScreen extends StatefulWidget {
  final Hotspot hotspot;
  final AudioService audioService;
  final bool autoPlay;

  const HotspotDetailScreen({
    super.key,
    required this.hotspot,
    required this.audioService,
    this.autoPlay = false,
  });

  @override
  State<HotspotDetailScreen> createState() => _HotspotDetailScreenState();
}

class _HotspotDetailScreenState extends State<HotspotDetailScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.autoPlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.audioService.play(widget.hotspot.audioFile);
      });
    }
  }

  @override
  void dispose() {
    widget.audioService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.hotspot;
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: const Color(0xFFF97316),
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                h.name,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  h.images.isNotEmpty
                      ? Image.asset(h.images.first, fit: BoxFit.cover)
                      : Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFF97316), Color(0xFFEAB308)],
                            ),
                          ),
                        ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.6),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  h.subtitle,
                  style: const TextStyle(
                    color: Color(0xFF9A3412),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                AudioPlayerWidget(
                  audioService: widget.audioService,
                  assetPath: h.audioFile,
                ),
                const SizedBox(height: 16),
                Text(
                  h.description,
                  style: const TextStyle(
                    color: Color(0xFF431407),
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
                if (h.images.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'BILDER',
                    style: TextStyle(
                      color: Color(0xFF9A3412),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: h.images.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 8),
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          h.images[i],
                          width: 130,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 130,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFFFED7AA),
                                  Color(0xFFF97316)
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
