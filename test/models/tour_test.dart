import 'package:flutter_test/flutter_test.dart';
import 'package:palma_app/models/tour.dart';
import 'package:palma_app/models/tour_stop.dart';

void main() {
  test('Tour.fromJson parses core fields', () {
    final t = Tour.fromJson({
      'id': 't1',
      'citypack_id': 'c1',
      'type': 'food_drink',
      'title': 'Tapas Route',
      'subtitle': 'Best bites',
      'description': 'A crawl',
      'hero_image': 'tour-images/tapas/hero.jpg',
      'price_cents': 49,
      'is_published': true,
      'distance_meters': 1200,
      'est_minutes': 45,
      'route_geojson': {'type': 'LineString', 'coordinates': []},
      'sort_order': 1,
    });
    expect(t.id, 't1');
    expect(t.type, 'food_drink');
    expect(t.priceCents, 49);
    expect(t.distanceMeters, 1200);
    expect(t.routeGeojson, isNotNull);
  });

  test('Tour.fromJson tolerates nulls', () {
    final t = Tour.fromJson({
      'id': 't2',
      'citypack_id': 'c1',
      'type': 'history_walk',
      'title': 'Walk',
      'is_published': false,
    });
    expect(t.priceCents, 0);
    expect(t.distanceMeters, isNull);
    expect(t.heroImage, isNull);
  });

  test('TourStop.fromJson parses hotspot-linked stop', () {
    final s = TourStop.fromJson({
      'id': 's1',
      'tour_id': 't1',
      'order_index': 0,
      'hotspot_id': 'h1',
      'arrival_radius_meters': 50,
    });
    expect(s.hotspotId, 'h1');
    expect(s.arrivalRadiusMeters, 50);
    expect(s.isCustom, isFalse);
  });

  test('TourStop.fromJson parses custom venue stop', () {
    final s = TourStop.fromJson({
      'id': 's2',
      'tour_id': 't1',
      'order_index': 1,
      'title': 'Bar Bóveda',
      'blurb': 'Try the bravas',
      'lat': 39.57,
      'lng': 2.65,
      'offer_text': '2-for-1',
      'redeem_code': 'TAPAS10',
    });
    expect(s.isCustom, isTrue);
    expect(s.title, 'Bar Bóveda');
    expect(s.lat, 39.57);
    expect(s.redeemCode, 'TAPAS10');
  });
}
