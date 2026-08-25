import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:just_audio/just_audio.dart';
import 'package:palma_app/services/audio_service.dart';

class MockAudioPlayer extends Mock implements AudioPlayer {}

void main() {
  setUpAll(() {
    registerFallbackValue(
        AudioSource.asset('assets/audio/catedral.mp3'));
  });

  group('AudioService', () {
    late MockAudioPlayer mockPlayer;
    late AudioService audioService;

    setUp(() {
      mockPlayer = MockAudioPlayer();
      audioService = AudioService(player: mockPlayer);
    });

    test('play loads the source and starts playback', () async {
      when(() => mockPlayer.setAudioSource(any()))
          .thenAnswer((_) async => null);
      when(() => mockPlayer.play()).thenAnswer((_) async {});

      await audioService.play('assets/audio/catedral.mp3');

      verify(() => mockPlayer.setAudioSource(any())).called(1);
      verify(() => mockPlayer.play()).called(1);
    });

    test('pause calls pause on the player', () async {
      when(() => mockPlayer.pause()).thenAnswer((_) async {});

      await audioService.pause();

      verify(() => mockPlayer.pause()).called(1);
    });

    test('stop calls stop on the player', () async {
      when(() => mockPlayer.stop()).thenAnswer((_) async {});

      await audioService.stop();

      verify(() => mockPlayer.stop()).called(1);
    });
  });
}
