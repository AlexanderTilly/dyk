import 'package:flutter_test/flutter_test.dart';
import 'package:palma_app/services/geo_fencing_service.dart';

void main() {
  group('GeoFencingService', () {
    test('triggeredIds starts empty', () {
      final service = GeoFencingService();
      expect(service.triggeredIds, isEmpty);
    });

    test('markTriggered adds id to triggeredIds', () {
      final service = GeoFencingService();
      service.markTriggered('catedral');
      expect(service.triggeredIds, contains('catedral'));
    });

    test('hasBeenTriggered returns true after markTriggered', () {
      final service = GeoFencingService();
      service.markTriggered('catedral');
      expect(service.hasBeenTriggered('catedral'), isTrue);
    });

    test('hasBeenTriggered returns false for unknown id', () {
      final service = GeoFencingService();
      expect(service.hasBeenTriggered('unknown'), isFalse);
    });

    test('resetSession clears triggeredIds', () {
      final service = GeoFencingService();
      service.markTriggered('catedral');
      service.resetSession();
      expect(service.triggeredIds, isEmpty);
    });
  });
}
