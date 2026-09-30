import 'package:flutter_test/flutter_test.dart';
import 'package:palma_app/services/ar_scene.dart';

ArScene sceneAt(List<double> bearings) => ArScene(
      title: 't',
      era: '1926',
      lat: 0,
      lng: 0,
      views: [
        for (final b in bearings)
          ArView(bearing: b, now: 'now_$b.jpg', then: 'then_$b.jpg'),
      ],
    );

void main() {
  group('angleBetween', () {
    test('is the short way round, not the long one', () {
      expect(angleBetween(350, 10), 20);
      expect(angleBetween(10, 350), 20);
    });

    test('never exceeds a half turn', () {
      for (var a = 0.0; a < 360; a += 17) {
        for (var b = 0.0; b < 360; b += 23) {
          expect(angleBetween(a, b), lessThanOrEqualTo(180));
        }
      }
    });

    test('handles headings past a full turn', () {
      expect(angleBetween(370, 10), 0);
    });
  });

  group('viewForHeading', () {
    test('picks the nearest bearing', () {
      final scene = sceneAt([0, 90, 180, 270]);
      expect(viewForHeading(scene, 80)!.bearing, 90);
      expect(viewForHeading(scene, 100)!.bearing, 90);
    });

    test('wraps: just short of north picks north, not west', () {
      final scene = sceneAt([0, 90, 180, 270]);
      expect(viewForHeading(scene, 350)!.bearing, 0);
    });

    test('works with three unevenly spaced views', () {
      final scene = sceneAt([0, 120, 240]);
      expect(viewForHeading(scene, 200)!.bearing, 240);
      expect(viewForHeading(scene, 59)!.bearing, 0);
      expect(viewForHeading(scene, 61)!.bearing, 120);
    });

    test('an empty scene has nothing to show rather than throwing', () {
      expect(viewForHeading(sceneAt([]), 0), isNull);
    });

    test('the shipped office scene answers for every heading', () {
      for (var h = 0.0; h < 360; h += 1) {
        expect(viewForHeading(officeScene, h), isNotNull);
      }
    });
  });
}
