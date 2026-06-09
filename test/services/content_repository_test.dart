import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palma_app/services/content_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ContentRepository', () {
    test('loadHotspots returns non-empty list', () async {
      final testJson = '''
      [
        {
          "id": "test",
          "name": "Test Place",
          "subtitle": "Test",
          "description": "A test place",
          "lat": 39.5671,
          "lng": 2.6498,
          "radius_meters": 50,
          "audio_file": "assets/audio/test.mp3",
          "images": [],
          "year": 2024
        }
      ]
      ''';
      ServicesBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        (message) async {
          return ByteData.view(
            Uint8List.fromList(testJson.codeUnits).buffer,
          );
        },
      );

      final repo = ContentRepository();
      final hotspots = await repo.loadHotspots();
      expect(hotspots.length, 1);
      expect(hotspots.first.id, 'test');
    });
  });
}
