// Smoke test: verify DykApp can be constructed with required dependencies.
import 'package:flutter_test/flutter_test.dart';
import 'package:palma_app/models/hot_deal.dart';
import 'package:palma_app/models/hotspot.dart';
import 'package:palma_app/services/app_state.dart';
import 'package:palma_app/services/audio_service.dart';
import 'package:palma_app/services/geo_fencing_service.dart';
import 'package:palma_app/services/notification_service.dart';
import 'package:palma_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('DykApp constructs without throwing', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final app = DykApp(
      appState: AppState(prefs),
      hotspots: const <Hotspot>[],
      deals: const <HotDeal>[],
      audioService: AudioService(),
      geoService: GeoFencingService(),
      notificationService: NotificationService(),
    );
    expect(app, isNotNull);
  });
}
