import 'package:flutter/material.dart';
import '../services/audio_service.dart';

class AudioPlayerWidget extends StatefulWidget {
  final AudioService audioService;
  final String assetPath;

  const AudioPlayerWidget({
    super.key,
    required this.audioService,
    required this.assetPath,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    widget.audioService.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    widget.audioService.durationStream.listen((dur) {
      if (mounted && dur != null) setState(() => _duration = dur);
    });
    widget.audioService.playerStateStream.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state.playing);
      }
    });
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress =
        _duration.inMilliseconds > 0
            ? _position.inMilliseconds / _duration.inMilliseconds
            : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF97316).withValues(alpha: 0.15),
            blurRadius: 8,
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🎧 LYSSNA PÅ BERÄTTELSEN',
            style: TextStyle(
              color: Color(0xFF9A3412),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: const Color(0xFFF97316),
              inactiveTrackColor: const Color(0xFFFED7AA),
              thumbColor: const Color(0xFFF97316),
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: (v) {
                final seek = Duration(
                  milliseconds: (v * _duration.inMilliseconds).toInt(),
                );
                widget.audioService.seekTo(seek);
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _format(_position),
                style: const TextStyle(
                    color: Color(0xFF9A3412), fontSize: 11),
              ),
              GestureDetector(
                onTap: () async {
                  if (_isPlaying) {
                    await widget.audioService.pause();
                  } else {
                    await widget.audioService.play(widget.assetPath);
                  }
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF97316),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              Text(
                _format(_duration),
                style: const TextStyle(
                    color: Color(0xFF9A3412), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
