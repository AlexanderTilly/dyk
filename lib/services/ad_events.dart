import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Counting what an advertiser actually bought.
///
/// An advertiser's first question is "how many people did you send me", and
/// it can only be answered if it was counted from the start. Two events:
/// `directions` when someone asks to be taken there, `arrival` when they turn
/// up. "Twelve asked, five walked in" is a different kind of number to sell
/// than impressions.
///
/// The server deduplicates per person per ad per day, so these are people
/// rather than taps. Nothing is billed yet — the volume is being learnt
/// first, because pricing something unmeasured is guessing.
class AdEvents {
  /// Ads someone asked directions to, with when they asked.
  static const _pendingKey = 'ad_directions_pending';

  /// How long a tap stays worth watching for an arrival. A tourist who asks
  /// for directions and shows up two days later was not sent by the ad.
  static const _window = Duration(hours: 24);

  /// Close enough to call it a visit. Tighter than a hotspot trigger: this
  /// claims someone walked into a specific doorway, and that claim ends up
  /// on an invoice.
  static const arrivalMeters = 60.0;

  static Future<void> _log(String adId, String kind) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userKey = prefs.getString('anon_install_id');
      if (userKey == null) return;
      await Supabase.instance.client.rpc('ad_event_log', params: {
        'p_ad_id': adId,
        'p_user_key': userKey,
        'p_kind': kind,
      });
    } catch (e) {
      // Losing a count must never cost the user their directions.
      debugPrint('ad_event_log($kind) failed: $e');
    }
  }

  /// Someone asked to be taken to this ad's venue.
  static Future<void> directionsTapped(String adId) async {
    await _log(adId, 'directions');
    final prefs = await SharedPreferences.getInstance();
    final pending = _read(prefs);
    pending[adId] = DateTime.now().toUtc().toIso8601String();
    await prefs.setString(_pendingKey, jsonEncode(pending));
  }

  /// Ads worth watching for an arrival right now.
  ///
  /// Only ads someone actually asked directions to. Logging an arrival for
  /// any ad the user happened to walk past would turn a meaningful number
  /// into a meaningless one — and it is the meaningful one being sold.
  static Future<Set<String>> awaitingArrival() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = _read(prefs);
    final cutoff = DateTime.now().toUtc().subtract(_window);
    final live = <String>{};
    var changed = false;
    pending.forEach((adId, iso) {
      final at = DateTime.tryParse(iso);
      if (at != null && at.isAfter(cutoff)) {
        live.add(adId);
      } else {
        changed = true;
      }
    });
    if (changed) {
      await prefs.setString(_pendingKey,
          jsonEncode({for (final id in live) id: pending[id]}));
    }
    return live;
  }

  /// They turned up. Recorded once per person per ad per day by the server,
  /// and stopped being watched here so a long lunch is not counted twice.
  static Future<void> arrived(String adId) async {
    await _log(adId, 'arrival');
    final prefs = await SharedPreferences.getInstance();
    final pending = _read(prefs)..remove(adId);
    await prefs.setString(_pendingKey, jsonEncode(pending));
  }

  static Map<String, String> _read(SharedPreferences prefs) {
    final raw = prefs.getString(_pendingKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      return (jsonDecode(raw) as Map).map(
        (k, v) => MapEntry(k as String, v as String),
      );
    } catch (_) {
      return {}; // corrupt entry is not worth crashing over
    }
  }
}
