import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

/// Plays looping background music during onboarding. A single shared player
/// so it survives across the onboarding screens and stops when finished.
class OnboardingMusic {
  static final AudioPlayer _player = AudioPlayer();
  static bool _started = false;
  static const _volume = 0.5;

  static Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      // just_audio_background requires a MediaItem tag on every source.
      await _player.setAudioSource(
        AudioSource.asset(
          'assets/audio/onboarding.mp3',
          tag: MediaItem(
            id: 'onboarding_music',
            title: 'Passim',
            artist: 'Passim',
          ),
        ),
        // Skip the quiet intro — the song has found its groove by 0:13.
        initialPosition: const Duration(seconds: 13),
      );
      await _player.setLoopMode(LoopMode.all);
      await _player.setVolume(_volume);
      await _player.play();
    } catch (_) {
      _started = false;
    }
  }

  /// Fade out over ~1.2 s instead of cutting off, then stop.
  static Future<void> stop() async {
    if (!_started) return;
    _started = false;
    try {
      const steps = 12;
      const stepDur = Duration(milliseconds: 100);
      for (var i = steps - 1; i >= 0; i--) {
        await _player.setVolume(_volume * i / steps);
        await Future.delayed(stepDur);
      }
      await _player.stop();
      await _player.setVolume(_volume); // ready for a potential restart
    } catch (_) {}
  }
}
