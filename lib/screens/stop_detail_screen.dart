import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../i18n/i18n.dart';
import '../models/tour_stop.dart';
import '../services/audio_service.dart';
import '../theme/dyk_theme.dart';

/// Detail page for a standalone venue stop (no linked hotspot) — same look
/// as the hotspot detail page, built from the stop's own content.
class StopDetailScreen extends StatelessWidget {
  final TourStop stop;
  final AudioService audioService;
  final VoidCallback? onContinueTour;

  const StopDetailScreen(
      {super.key,
      required this.stop,
      required this.audioService,
      this.onContinueTour});

  @override
  Widget build(BuildContext context) {
    final hasAudio = stop.audioPath != null && stop.audioPath!.isNotEmpty;
    final img = stop.image;
    return Scaffold(
      backgroundColor: PassimColors.ink,
      bottomNavigationBar: onContinueTour == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: DykColors.yellow,
                        foregroundColor: DykColors.black),
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(tr('continue_tour'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 16)),
                    onPressed: onContinueTour,
                  ),
                ),
              ),
            ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: img != null ? 260 : 120,
            pinned: true,
            backgroundColor: PassimColors.ink,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  img != null && img.isNotEmpty
                      ? CachedNetworkImage(imageUrl: img, fit: BoxFit.cover)
                      : Container(color: Colors.black26),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.center,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, PassimColors.ink],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stop.title ?? '',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          height: 1.15,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  if (hasAudio) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: DykColors.yellow,
                            foregroundColor: DykColors.black,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14)),
                        icon: const Icon(Icons.play_arrow),
                        label: Text(tr('listen_story'),
                            style: const TextStyle(
                                fontWeight: FontWeight.w900)),
                        onPressed: () => audioService.play(stop.audioPath!,
                            title: stop.title, artUrl: stop.image),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (stop.blurb != null && stop.blurb!.isNotEmpty)
                    Text(stop.blurb!,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                            height: 1.55)),
                  if (stop.offerText != null) ...[
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: DykColors.yellow.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color:
                                DykColors.yellow.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(stop.offerText!,
                              style: const TextStyle(
                                  color: DykColors.yellow,
                                  fontWeight: FontWeight.w800)),
                          if (stop.redeemCode != null &&
                              stop.redeemCode!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                decoration: BoxDecoration(
                                  color: DykColors.yellow,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: DykColors.black, width: 2),
                                ),
                                child: Text('CODE: ${stop.redeemCode}',
                                    style: const TextStyle(
                                        color: DykColors.black,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 17,
                                        letterSpacing: 1)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (stop.ctaText != null && stop.ctaUrl != null) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: DykColors.yellow,
                          side: const BorderSide(
                              color: DykColors.yellow, width: 1.5),
                        ),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: Text(stop.ctaText!,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900)),
                        onPressed: () => launchUrl(Uri.parse(stop.ctaUrl!),
                            mode: LaunchMode.externalApplication),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
