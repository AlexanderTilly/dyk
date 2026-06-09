// Smoke test: verify PalmaApp can be constructed with required dependencies.
import 'package:flutter_test/flutter_test.dart';
import 'package:palma_app/models/hotspot.dart';
import 'package:palma_app/services/audio_service.dart';
import 'package:palma_app/services/geo_fencing_service.dart';
import 'package:palma_app/services/notification_service.dart';
import 'package:palma_app/main.dart';

void main() {
  testWidgets('PalmaApp constructs without throwing', (WidgetTester tester) async {
    final app = PalmaApp(
      hotspots: const <Hotspot>[],
      audioService: AudioService(),
      geoService: GeoFencingService(),
      notificationService: NotificationService(),
    );
    expect(app, isNotNull);
  });
}
