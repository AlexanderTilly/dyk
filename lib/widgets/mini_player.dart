import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../i18n/i18n.dart';
import 'package:just_audio/just_audio.dart';

import '../services/audio_service.dart';
import '../theme/dyk_theme.dart';

/// Slim now-playing bar shown above the bottom nav whenever audio is loaded.
/// Play/pause and stop from anywhere; tap the title to jump back to the
/// hotspot the narration belongs to.
class MiniPlayer extends StatelessWidget {
  final AudioService audioService;
  final void Function(String hotspotId)? onOpenHotspot;

  const MiniPlayer({
    super.key,
    required this.audioService,
    this.onOpenHotspot,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NowPlayingInfo?>(
      valueListenable: audioService.nowPlaying,
      builder: (context, info, _) {
        if (info == null) return const SizedBox.shrink();
        return StreamBuilder<PlayerState>(
          stream: audioService.playerStateStream,
          builder: (context, snap) {
            final state = snap.data;
            final playing = state?.playing ?? false;
            final completed =
                state?.processingState == ProcessingState.completed;
            return Container(
              height: 54,
              decoration: BoxDecoration(
                color: Color(0xFF1A1A1A),
                border: Border(
                  top: BorderSide(color: DykColors.yellow, width: 2),
                ),
              ),
              child: Row(
                children: [
                  // Artwork (or a headphones fallback).
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: info.artUrl != null
                          ? CachedNetworkImage(
                              imageUrl: info.artUrl!,
                              width: 38,
                              height: 38,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 38,
                              height: 38,
                              color: Colors.white10,
                              child: const Icon(Icons.headphones,
                                  color: DykColors.yellow, size: 20),
                            ),
                    ),
                  ),
                  // Title — tap to reopen the hotspot's detail page.
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: info.hotspotId != null
                          ? () => onOpenHotspot?.call(info.hotspotId!)
                          : null,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            info.title ?? 'Did You Know?',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13),
                          ),
                          if (info.hotspotId != null)
                            Text(tr('tap_to_open'),
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.replay_10,
                      color: Colors.white70, size: 20),
                  onPressed: () =>
                      audioService.skip(const Duration(seconds: -10)),
                ),
                IconButton(
                    icon: Icon(
                      completed
                          ? Icons.replay
                          : (playing ? Icons.pause : Icons.play_arrow),
                      color: DykColors.yellow,
                      size: 26,
                    ),
                    onPressed: () {
                      if (completed) {
                        audioService.seekTo(Duration.zero);
                        audioService.resume();
                      } else if (playing) {
                        audioService.pause();
                      } else {
                        audioService.resume();
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white54, size: 22),
                    onPressed: audioService.stop,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
