import 'package:flutter_test/flutter_test.dart';
import 'package:palma_app/models/hotspot.dart';

void main() {
  group('Hotspot', () {
    final json = {
      'id': 'catedral',
      'name': 'Catedral de Mallorca',
      'subtitle': 'La Seu • Grundad 1229',
      'description': 'Katedralen byggdes av Jaime I.',
      'lat': 39.5671,
      'lng': 2.6498,
      'radius_meters': 50,
      'audio_file': 'assets/audio/catedral.mp3',
      'images': ['assets/images/catedral_1.jpg'],
      'year': 1229,
    };

    test('fromJson creates correct Hotspot', () {
      final hotspot = Hotspot.fromJson(json);
      expect(hotspot.id, 'catedral');
      expect(hotspot.name, 'Catedral de Mallorca');
      expect(hotspot.lat, 39.5671);
      expect(hotspot.radiusMeters, 50);
      expect(hotspot.images.length, 1);
    });

    test('toJson round-trips correctly', () {
      final hotspot = Hotspot.fromJson(json);
      final result = hotspot.toJson();
      expect(result['id'], 'catedral');
      expect(result['lat'], 39.5671);
    });
  });
}
