import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../i18n/i18n.dart';
import '../models/city_pack.dart';
import '../models/hot_deal.dart';
import '../models/hotspot.dart';
import '../models/internal_ad.dart';
import '../models/pickpocket_report.dart';
import '../models/tour.dart';
import '../models/tour_stop.dart';

/// Interface so tests can stub the repository without touching Supabase.
abstract class DykRepositoryBase {
  Future<List<CityPack>> loadCityPacks();
  Future<List<Hotspot>> loadHotspots(String citypackId);
  Future<List<HotDeal>> loadDeals(String citypackId);
  Future<Map<String, dynamic>?> startRedeem(String dealId, String? userKey);
  Future<List<InternalAd>> loadAds();
  Future<List<PickpocketReport>> loadPickpocketReports();
  Future<String?> reportPickpocket({
    required double lat,
    required double lng,
    String? description,
  });
  Future<List<Tour>> loadTours(String citypackId);
  Future<List<TourStop>> loadTourStops(String tourId);
  Future<Set<String>> loadTourProgress(String tourId);
  Future<bool> hasTour(String tourId);
  Future<String?> unlockTour(String tourId);
  Future<void> recordTourVisit(String tourId, String stopId);
  Future<(bool, Set<String>)> getEntitlements();
  Future<String?> unlockCity(String citypackId);
  Future<String?> setPremium();
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
      for (final r in rows) {
        final img = r['header_image'] as String?;
        final slash = img?.indexOf('/') ?? -1;
        if (img != null && slash > 0) {
          r['header_image'] = _client.storage
              .from(img.substring(0, slash))
              .getPublicUrl(img.substring(slash + 1));
        }
      }
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
          .order('sort_order', ascending: true);

      // Overlay content translations for the chosen app language (English is
      // the master; missing translations fall back to the English fields).
      final lang = I18n.instance.code;
      Map<String, List<String>>? factsOverride;
      if (lang != 'en' && rows.isNotEmpty) {
        try {
          final ids = rows.map((r) => r['id'] as String).toList();
          final trs = await _client
              .from('hotspot_translations')
              .select()
              .eq('lang', lang)
              .inFilter('hotspot_id', ids);
          final byId = {for (final t in trs) t['hotspot_id'] as String: t};
          factsOverride = {};
          for (final r in rows) {
            final t = byId[r['id'] as String];
            if (t == null) continue;
            for (final f in ['name', 'subtitle', 'description']) {
              final v = t[f] as String?;
              if (v != null && v.isNotEmpty) r[f] = v;
            }
            final facts = t['facts'];
            if (facts is List && facts.isNotEmpty) {
              factsOverride[r['id'] as String] =
                  facts.map((f) => f.toString()).toList();
            }
          }
        } catch (e) {
          debugPrint('translations overlay failed: $e');
        }
      }

      final hotspots = rows.map<Hotspot>((r) => Hotspot.fromJson(r)).toList();
      return _attachMedia(hotspots, factsOverride: factsOverride);
    } catch (e) {
      debugPrint('DykRepository.loadHotspots failed: $e');
      return [];
    }
  }

  Future<List<InternalAd>> loadAds() async {
    try {
      final rows = await _client
          .from('internal_ads')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);
      return rows.map<InternalAd>((r) => InternalAd.fromJson(r)).toList();
    } catch (e) {
      debugPrint('DykRepository.loadAds failed: $e');
      return [];
    }
  }

  /// Pulls uploaded images + audio from hotspot_media and overlays them onto
  /// each hotspot as public Storage URLs (falls back to bundled assets if a
  /// hotspot has no uploaded media yet).
  Future<List<Hotspot>> _attachMedia(List<Hotspot> hotspots,
      {Map<String, List<String>>? factsOverride}) async {
    if (hotspots.isEmpty) return hotspots;
    try {
      final ids = hotspots.map((h) => h.id).toList();
      final media = await _client
          .from('hotspot_media')
          .select()
          .inFilter('hotspot_id', ids)
          .order('sort_order', ascending: true);
      final factRows = await _client
          .from('hotspot_facts')
          .select()
          .inFilter('hotspot_id', ids)
          .order('sort_order', ascending: true);

      final imagesByHotspot = <String, List<String>>{};
      final audioByHotspot = <String, String>{};
      // Rank of the chosen audio: 0 = app language, 1 = English fallback,
      // 2 = whatever exists. Lower wins.
      final audioRank = <String, int>{};
      final videosByHotspot = <String, List<String>>{};
      final captionsByHotspot = <String, List<String?>>{};
      final factsByHotspot = <String, List<String>>{};
      final appLang = I18n.instance.code;

      for (final f in factRows) {
        (factsByHotspot[f['hotspot_id'] as String] ??= [])
            .add(f['text'] as String);
      }

      for (final m in media) {
        final hotspotId = m['hotspot_id'] as String;
        final path = m['storage_path'] as String; // e.g. "hotspot-images/slug/file.jpg"
        final slash = path.indexOf('/');
        if (slash < 0) continue;
        final bucket = path.substring(0, slash);
        final objectPath = path.substring(slash + 1);
        final url = _client.storage.from(bucket).getPublicUrl(objectPath);

        if (m['media_type'] == 'image') {
          (imagesByHotspot[hotspotId] ??= []).add(url);
          (captionsByHotspot[hotspotId] ??= []).add(m['caption'] as String?);
        } else if (m['media_type'] == 'audio') {
          final lang = (m['lang'] as String?) ?? 'en';
          final rank = lang == appLang ? 0 : (lang == 'en' ? 1 : 2);
          if (rank < (audioRank[hotspotId] ?? 3)) {
            audioByHotspot[hotspotId] = url;
            audioRank[hotspotId] = rank;
          }
        } else if (m['media_type'] == 'video') {
          (videosByHotspot[hotspotId] ??= []).add(url);
        }
      }

      return hotspots
          .map((h) => h.copyWith(
                images: imagesByHotspot[h.id],
                imageCaptions: captionsByHotspot[h.id],
                audioFile: audioByHotspot[h.id],
                facts: factsOverride?[h.id] ?? factsByHotspot[h.id],
                videos: videosByHotspot[h.id],
              ))
          .toList();
    } catch (e) {
      debugPrint('DykRepository._attachMedia failed: $e');
      return hotspots; // fall back to bundled assets
    }
  }

  /// All currently-active (non-expired) pickpocket reports.
  Future<List<PickpocketReport>> loadPickpocketReports() async {
    try {
      final rows = await _client.rpc('get_pickpocket_reports');
      return (rows as List)
          .map<PickpocketReport>((r) => PickpocketReport.fromJson(r))
          .toList();
    } catch (e) {
      debugPrint('DykRepository.loadPickpocketReports failed: $e');
      return [];
    }
  }

  /// File a pickpocket report at the given location. Returns null on success
  /// or an error message (e.g. not signed in).
  Future<String?> reportPickpocket({
    required double lat,
    required double lng,
    String? description,
  }) async {
    try {
      await _client.rpc('report_pickpocket', params: {
        'p_lat': lat,
        'p_lng': lng,
        'p_description': description,
      });
      return null;
    } catch (e) {
      debugPrint('DykRepository.reportPickpocket failed: $e');
      return 'Could not submit report. Please try again.';
    }
  }

  Future<List<Tour>> loadTours(String citypackId) async {
    try {
      final rows = await _client
          .from('tours')
          .select()
          .eq('citypack_id', citypackId)
          .eq('is_published', true)
          .order('sort_order', ascending: true);

      // Overlay tour translations for the chosen app language.
      final lang = I18n.instance.code;
      if (lang != 'en' && rows.isNotEmpty) {
        try {
          final ids = rows.map((r) => r['id'] as String).toList();
          final trs = await _client
              .from('tour_translations')
              .select()
              .eq('lang', lang)
              .inFilter('tour_id', ids);
          final byId = {for (final t in trs) t['tour_id'] as String: t};
          for (final r in rows) {
            final t = byId[r['id'] as String];
            if (t == null) continue;
            for (final f in ['title', 'subtitle', 'description']) {
              final v = t[f] as String?;
              if (v != null && v.isNotEmpty) r[f] = v;
            }
          }
        } catch (e) {
          debugPrint('tour translations overlay failed: $e');
        }
      }

      return rows.map<Tour>((r) {
        for (final field in ['hero_image', 'creator_avatar']) {
          final path = r[field] as String?;
          if (path != null && path.contains('/') && !path.startsWith('http')) {
            final slash = path.indexOf('/');
            r[field] = _client.storage
                .from(path.substring(0, slash))
                .getPublicUrl(path.substring(slash + 1));
          }
        }
        return Tour.fromJson(r);
      }).toList();
    } catch (e) {
      debugPrint('DykRepository.loadTours failed: $e');
      return [];
    }
  }

  Future<List<TourStop>> loadTourStops(String tourId) async {
    try {
      final rows = await _client
          .from('tour_stops')
          .select()
          .eq('tour_id', tourId)
          .order('order_index', ascending: true);

      // Look up names for hotspot-linked stops so they show the real place
      // name ("Catedral") instead of "Stop N".
      final hotspotIds = rows
          .map((r) => r['hotspot_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();
      final names = <String, String>{};
      final hotspotAudio = <String, String>{}; // hotspotId → public audio URL
      final hotspotImage = <String, String>{}; // hotspotId → first image URL
      if (hotspotIds.isNotEmpty) {
        final hs = await _client
            .from('hotspots')
            .select('id, name')
            .inFilter('id', hotspotIds);
        for (final h in hs) {
          names[h['id'] as String] = h['name'] as String;
        }
        // The hotspot's own narration + header image — used when a stop has
        // no tour-specific override.
        final mediaRows = await _client
            .from('hotspot_media')
            .select('hotspot_id, media_type, storage_path')
            .inFilter('media_type', ['audio', 'image'])
            .inFilter('hotspot_id', hotspotIds)
            .order('sort_order', ascending: true);
        final appLang = I18n.instance.code;
        final audioRank = <String, int>{}; // 0 = app language, 1 = English
        for (final a in mediaRows) {
          final hid = a['hotspot_id'] as String;
          final path = a['storage_path'] as String;
          final slash = path.indexOf('/');
          if (slash < 0) continue;
          final url = _client.storage
              .from(path.substring(0, slash))
              .getPublicUrl(path.substring(slash + 1));
          if (a['media_type'] == 'audio') {
            final lang = (a['lang'] as String?) ?? 'en';
            final rank = lang == appLang ? 0 : (lang == 'en' ? 1 : 2);
            if (rank < (audioRank[hid] ?? 3)) {
              hotspotAudio[hid] = url;
              audioRank[hid] = rank;
            }
          } else {
            if (hotspotImage.containsKey(hid)) continue; // first image wins
            hotspotImage[hid] = url;
          }
        }
      }

      return rows.map<TourStop>((r) {
        // Resolve storage paths for stop image/audio to public URLs.
        for (final field in ['image', 'audio_path']) {
          final path = r[field] as String?;
          if (path != null && path.contains('/')) {
            final slash = path.indexOf('/');
            r[field] = _client.storage
                .from(path.substring(0, slash))
                .getPublicUrl(path.substring(slash + 1));
          }
        }
        // Fill the title from the linked hotspot's name when the stop has none.
        final hid = r['hotspot_id'] as String?;
        if ((r['title'] == null || (r['title'] as String).isEmpty) &&
            hid != null &&
            names.containsKey(hid)) {
          r['title'] = names[hid];
        }
        // No tour-specific narration → fall back to the hotspot's own audio.
        if ((r['audio_path'] == null ||
                (r['audio_path'] as String).isEmpty) &&
            hid != null &&
            hotspotAudio.containsKey(hid)) {
          r['audio_path'] = hotspotAudio[hid];
        }
        // No stop image → fall back to the hotspot's header image.
        if ((r['image'] == null || (r['image'] as String).isEmpty) &&
            hid != null &&
            hotspotImage.containsKey(hid)) {
          r['image'] = hotspotImage[hid];
        }
        return TourStop.fromJson(r);
      }).toList();
    } catch (e) {
      debugPrint('DykRepository.loadTourStops failed: $e');
      return [];
    }
  }

  Future<Set<String>> loadTourProgress(String tourId) async {
    try {
      final rows = await _client
          .from('tour_progress')
          .select('stop_id')
          .eq('tour_id', tourId);
      return rows.map<String>((r) => r['stop_id'] as String).toSet();
    } catch (e) {
      debugPrint('DykRepository.loadTourProgress failed: $e');
      return <String>{};
    }
  }

  Future<bool> hasTour(String tourId) async {
    try {
      final res = await _client.rpc('has_tour', params: {'p_tour_id': tourId});
      return res == true;
    } catch (e) {
      debugPrint('DykRepository.hasTour failed: $e');
      return false;
    }
  }

  Future<String?> unlockTour(String tourId) async {
    try {
      await _client.rpc('unlock_tour', params: {'p_tour_id': tourId});
      return null;
    } catch (e) {
      debugPrint('DykRepository.unlockTour failed: $e');
      return 'Could not unlock. Please sign in and try again.';
    }
  }

  Future<void> recordTourVisit(String tourId, String stopId) async {
    try {
      await _client.rpc('record_tour_visit',
          params: {'p_tour_id': tourId, 'p_stop_id': stopId});
    } catch (e) {
      debugPrint('DykRepository.recordTourVisit failed: $e');
    }
  }

  Future<(bool, Set<String>)> getEntitlements() async {
    try {
      final res = await _client.rpc('get_entitlements');
      final map = res as Map<String, dynamic>;
      final premium = map['is_premium'] == true;
      final cities = ((map['cities'] as List?) ?? [])
          .map((e) => e.toString())
          .toSet();
      return (premium, cities);
    } catch (e) {
      debugPrint('DykRepository.getEntitlements failed: $e');
      return (false, <String>{});
    }
  }

  Future<String?> unlockCity(String citypackId) async {
    try {
      await _client.rpc('unlock_city', params: {'p_citypack_id': citypackId});
      return null;
    } catch (e) {
      debugPrint('DykRepository.unlockCity failed: $e');
      return 'Could not unlock. Please sign in and try again.';
    }
  }

  Future<String?> setPremium() async {
    try {
      await _client.rpc('set_premium');
      return null;
    } catch (e) {
      debugPrint('DykRepository.setPremium failed: $e');
      return 'Could not activate premium. Please sign in and try again.';
    }
  }

  Future<List<HotDeal>> loadDeals(String citypackId) async {
    try {
      final rows = await _client
          .from('hot_deals')
          .select('*, deal_media(*)')
          .eq('citypack_id', citypackId)
          .eq('is_active', true);
      String? toUrl(String? path) {
        if (path == null || !path.contains('/') || path.startsWith('http')) {
          return path;
        }
        final slash = path.indexOf('/');
        return _client.storage
            .from(path.substring(0, slash))
            .getPublicUrl(path.substring(slash + 1));
      }

      for (final r in rows) {
        r['header_image'] = toUrl(r['header_image'] as String?);
        for (final m in (r['deal_media'] as List? ?? const [])) {
          m['storage_path'] = toUrl(m['storage_path'] as String?);
        }
      }
      return rows.map<HotDeal>((r) => HotDeal.fromJson(r)).toList();
    } catch (e) {
      debugPrint('DykRepository.loadDeals failed: $e');
      return [];
    }
  }

  /// Explorer taps "Redeem" — the server issues a one-time code (15 min).
  /// Returns {code, expires_at, mode, business, offer} or {error}.
  Future<Map<String, dynamic>?> startRedeem(
      String dealId, String? userKey) async {
    try {
      final res = await _client.rpc('deal_redeem_start', params: {
        'p_deal_id': dealId,
        'p_user_key': userKey,
      });
      return (res as Map).cast<String, dynamic>();
    } catch (e) {
      debugPrint('DykRepository.startRedeem failed: $e');
      return null;
    }
  }
}
