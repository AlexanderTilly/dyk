import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/city_pack.dart';
import '../models/hot_deal.dart';
import '../models/hotspot.dart';

/// Interface so tests can stub the repository without touching Supabase.
abstract class DykRepositoryBase {
  Future<List<CityPack>> loadCityPacks();
  Future<List<Hotspot>> loadHotspots(String citypackId);
  Future<List<HotDeal>> loadDeals(String citypackId);
}

/// Loads DYK content from Supabase. Returns empty lists when offline so the
/// app can fall back to bundled content instead of crashing.
class DykRepository implements DykRepositoryBase {
  final SupabaseClient _client;

  DykRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<List<CityPack>> loadCityPacks() async {
    try {
      final rows =
          await _client.from('citypacks').select().eq('is_published', true);
      return rows.map<CityPack>((r) => CityPack.fromJson(r)).toList();
    } catch (e) {
      debugPrint('DykRepository.loadCityPacks failed: $e');
      return [];
    }
  }

  Future<List<Hotspot>> loadHotspots(String citypackId) async {
    try {
      final rows = await _client
          .from('hotspots')
          .select()
          .eq('citypack_id', citypackId)
          .order('sort_order');
      return rows.map<Hotspot>((r) => Hotspot.fromJson(r)).toList();
    } catch (e) {
      debugPrint('DykRepository.loadHotspots failed: $e');
      return [];
    }
  }

  Future<List<HotDeal>> loadDeals(String citypackId) async {
    try {
      final rows = await _client
          .from('hot_deals')
          .select()
          .eq('citypack_id', citypackId)
          .eq('is_active', true);
      return rows.map<HotDeal>((r) => HotDeal.fromJson(r)).toList();
    } catch (e) {
      debugPrint('DykRepository.loadDeals failed: $e');
      return [];
    }
  }
}
