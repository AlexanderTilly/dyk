import 'package:just_audio/just_audio.dart';

class AudioService {
  final AudioPlayer _player;

  AudioService({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  Future<void> play(String assetPath) async {
    await _player.setAsset(assetPath);
    await _player.play();
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> stop() async {
    await _player.stop();
  }

  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
  }

  void dispose() {
    _player.dispose();
  }
}
