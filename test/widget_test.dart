// Smoke test: verify DykApp can be constructed with required dependencies.
import 'package:flutter_test/flutter_test.dart';
import 'package:palma_app/models/city_pack.dart';
import 'package:palma_app/models/hot_deal.dart';
import 'package:palma_app/models/hotspot.dart';
import 'package:palma_app/models/internal_ad.dart';
import 'package:palma_app/models/pickpocket_report.dart';
import 'package:palma_app/models/tour.dart';
import 'package:palma_app/models/tour_stop.dart';
import 'package:palma_app/services/app_state.dart';
import 'package:palma_app/services/audio_service.dart';
import 'package:palma_app/services/geo_fencing_service.dart';
import 'package:palma_app/services/notification_log.dart';
import 'package:palma_app/services/notification_service.dart';
import 'package:palma_app/services/saved_store.dart';
import 'package:palma_app/main.dart';
import 'package:palma_app/services/dyk_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('DykApp constructs without throwing', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final app = DykApp(
      appState: AppState(prefs),
      notificationLog: NotificationLog(prefs),
      savedStore: SavedStore(prefs),
      dykRepo: FakeDykRepository(),
      cityPacks: const <CityPack>[],
      hotspots: const <Hotspot>[],
      deals: const <HotDeal>[],
      audioService: AudioService(),
      geoService: GeoFencingService(),
      notificationService: NotificationService(),
    );
    expect(app, isNotNull);
  });
}

/// Avoids touching Supabase.instance in tests.
class FakeDykRepository implements DykRepositoryBase {
  @override
  Future<List<CityPack>> loadCityPacks() async => [];
  @override
  Future<List<Hotspot>> loadHotspots(String citypackId) async => [];
  @override
  Future<List<HotDeal>> loadDeals(String citypackId) async => [];
  @override
  Future<Map<String, dynamic>?> startRedeem(String dealId, String? userKey) async => null;
  @override
  Future<List<InternalAd>> loadAds() async => [];
  @override
  Future<List<PickpocketReport>> loadPickpocketReports() async => [];
  @override
  Future<String?> reportPickpocket({
    required double lat,
    required double lng,
    String? description,
  }) async =>
      null;
  @override
  Future<List<Tour>> loadTours(String citypackId) async => [];
  @override
  Future<List<TourStop>> loadTourStops(String tourId) async => [];
  @override
  Future<Set<String>> loadTourProgress(String tourId) async => {};
  @override
  Future<bool> hasTour(String tourId) async => false;
  @override
  Future<String?> unlockTour(String tourId) async => null;
  @override
  Future<void> recordTourVisit(String tourId, String stopId) async {}
  @override
  Future<(bool, Set<String>)> getEntitlements() async => (false, <String>{});
  @override
  Future<String?> unlockCity(String citypackId) async => null;
  @override
  Future<String?> setPremium() async => null;
}
