import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// The sound that plays when you reach a place.
///
/// Its own player, deliberately not [AudioService]'s. That one owns the
/// narration and the media session — the lock-screen controls, the
/// notification, what the car stereo shows. A four-second chime has no
/// business appearing there, and routing it through the same player would
/// stop whatever story was mid-sentence.
///
/// Four seconds is the length of the arrival animation, not a coincidence:
/// the two are one moment, and the narration waits for both.
class ArrivalCue {

  /// How long the caller should hold the narration back. Read from the file
  /// once it has loaded, so re-cutting the sound changes the timing without
  /// anyone having to remember this constant.
  static const fallbackLength = Duration(milliseconds: 4000);

  final AudioPlayer _player;
  ArrivalCue({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  Duration _length = fallbackLength;
  Duration get length => _length;

  /// Plays from the start. Safe to call again while it is still ringing — a
  /// second arrival restarts the cue rather than layering two copies, which
  /// is what happens in the old town where places sit a minute apart.
  Future<void> play() async {
    try {
      await _player.setAsset('assets/audio/arrival.mp3');
      _length = _player.duration ?? fallbackLength;
      await _player.seek(Duration.zero);
      await _player.play();
    } catch (e) {
      // A missing or unplayable cue must never block an arrival: the animation
      // still runs and the story still starts.
      debugPrint('ArrivalCue.play failed: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    try {
      await _player.dispose();
    } catch (_) {}
  }
}
