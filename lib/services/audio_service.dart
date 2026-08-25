import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

/// What's currently loaded in the player — drives the in-app mini player.
class NowPlayingInfo {
  final String source;
  final String? title;
  final String? artUrl;
  final String? hotspotId; // set when the audio belongs to a hotspot

  const NowPlayingInfo({
    required this.source,
    this.title,
    this.artUrl,
    this.hotspotId,
  });
}

class AudioService {
  final AudioPlayer _player;

  /// Null when nothing is loaded. The mini player listens to this.
  final ValueNotifier<NowPlayingInfo?> nowPlaying = ValueNotifier(null);

  AudioService({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<double> get speedStream => _player.speedStream;
  double get speed => _player.speed;

  // Accepts either a bundled asset path or a remote http(s) URL. The title
  // and artwork show on the lock-screen / notification media controls.
  Future<void> play(String source,
      {String? title, String? artUrl, String? hotspotId}) async {
    final tag = MediaItem(
      id: source,
      title: title ?? 'Did You Know?',
      artist: 'Did You Know?',
      artUri: artUrl != null ? Uri.tryParse(artUrl) : null,
    );
    nowPlaying.value = NowPlayingInfo(
      source: source,
      title: title,
      artUrl: artUrl,
      hotspotId: hotspotId,
    );
    if (source.startsWith('http://') || source.startsWith('https://')) {
      await _player.setAudioSource(
          AudioSource.uri(Uri.parse(source), tag: tag));
    } else {
      await _player.setAudioSource(AudioSource.asset(source, tag: tag));
    }
    await _player.play();
  }

  /// Resume the already-loaded source without restarting it.
  Future<void> resume() async {
    await _player.play();
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> stop() async {
    await _player.stop();
    nowPlaying.value = null;
  }

  /// Jump ±[delta] from the current position, clamped to the track.
  Future<void> skip(Duration delta) async {
    final dur = _player.duration ?? Duration.zero;
    var target = _player.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (dur > Duration.zero && target > dur) target = dur;
    await _player.seek(target);
  }

  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
  }

  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
  }

  void dispose() {
    _player.dispose();
  }
}
