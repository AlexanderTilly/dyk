import 'package:flutter_test/flutter_test.dart';
import 'package:palma_app/models/city_pack.dart';
import 'package:palma_app/models/hot_deal.dart';
import 'package:palma_app/models/hotspot.dart';

void main() {
  test('HotDeal.fromJson parses supabase row', () {
    final deal = HotDeal.fromJson({
      'id': 'abc-123',
      'business_name': 'Café Palma',
      'offer_text': '2-for-1 coffee',
      'redeem_code': 'PALMA25',
      'lat': 39.57,
      'lng': 2.65,
      'radius_meters': 80,
    });
    expect(deal.businessName, 'Café Palma');
    expect(deal.redeemCode, 'PALMA25');
    expect(deal.radiusMeters, 80);
  });

  test('HotDeal.fromJson handles missing redeem_code', () {
    final deal = HotDeal.fromJson({
      'id': 'abc-123',
      'business_name': 'X',
      'offer_text': 'Y',
      'lat': 1.0,
      'lng': 2.0,
      'radius_meters': 50,
    });
    expect(deal.redeemCode, isNull);
  });

  test('CityPack.fromJson parses supabase row', () {
    final pack = CityPack.fromJson({
      'id': 'p1',
      'name': 'Palma de Mallorca',
      'city': 'Palma',
      'country': 'Spain',
      'description': 'desc',
      'price_sek': 49,
    });
    expect(pack.name, 'Palma de Mallorca');
    expect(pack.priceSek, 49);
  });

  test('Hotspot.fromJson defaults category and is_free', () {
    final h = Hotspot.fromJson({
      'id': 'h1',
      'name': 'Catedral',
      'subtitle': 's',
      'description': 'd',
      'lat': 39.5,
      'lng': 2.6,
      'radius_meters': 60,
      'audio_file': 'a.mp3',
      'images': ['i.jpg'],
      'year': 1229,
    });
    expect(h.category, 'history');
    expect(h.isFree, false);
  });

  test('Hotspot.fromJson reads category and is_free from supabase', () {
    final h = Hotspot.fromJson({
      'id': 'h2',
      'name': 'Plaça Major',
      'lat': 39.5,
      'lng': 2.6,
      'radius_meters': 50,
      'category': 'funfact',
      'is_free': true,
    });
    expect(h.category, 'funfact');
    expect(h.isFree, true);
    expect(h.audioFile, '');
    expect(h.images, isEmpty);
  });
}
