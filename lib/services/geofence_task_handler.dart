import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _supabaseUrl = 'https://jqykkyhoxpykhixwgwyw.supabase.co';
const _anonKey = 'sb_publishable_HCRDnKdePmnT0ukTyVlFCg_q0MRPyhK';

// Keys shared between the UI isolate and the background service isolate.
const kFgHotspots = 'fg_hotspots';
const kFgDeals = 'fg_deals';
// Published cities (with center coords), written by the UI isolate.
const kFgCities = 'fg_cities';
// The city id we last greeted the user in — so we notify once per arrival.
const kFgLastCity = 'fg_last_city';
// Same key AppState uses, so interest toggles take effect live.
const kInterests = 'interests';
const _defaultInterests = ['history', 'otium', 'headline', 'hotdeal'];
const kNotificationLog = 'notification_log';

// The background isolate can't reach the app's I18n singleton — a minimal
// translation table driven by the same 'app_lang' preference.
const _notifStrings = <String, Map<String, String>>{
  'en': {
    'now_at': 'You are now at',
    'tap_story': 'Tap to hear the story',
    'welcome': 'Welcome to',
    'welcome_sub': 'Tap to unlock its stories, myths & hidden gems.',
  },
  'es': {
    'now_at': 'Estás en',
    'tap_story': 'Toca para escuchar la historia',
    'welcome': 'Bienvenido a',
    'welcome_sub': 'Toca para descubrir sus historias, mitos y joyas ocultas.',
  },
  'ca': {
    'now_at': 'Ets a',
    'tap_story': 'Toca per escoltar la història',
    'welcome': 'Benvingut a',
    'welcome_sub': 'Toca per descobrir històries, mites i racons amagats.',
  },
  'de': {
    'now_at': 'Du bist jetzt an:',
    'tap_story': 'Tippe, um die Geschichte zu hören',
    'welcome': 'Willkommen in',
    'welcome_sub': 'Tippe für Geschichten, Mythen & versteckte Schätze.',
  },
};

String _ntr(SharedPreferences prefs, String key) {
  final lang = prefs.getString('app_lang') ?? 'en';
  return _notifStrings[lang]?[key] ?? _notifStrings['en']![key]!;
}

@pragma('vm:entry-point')
void startGeofenceCallback() {
  FlutterForegroundTask.setTaskHandler(GeofenceTaskHandler());
}

/// Runs in a separate isolate kept alive by the foreground service.
/// Every tick it reads the current location and fires a notification when
/// the user enters a hotspot or deal zone — even with the app backgrounded.
class GeofenceTaskHandler extends TaskHandler {
  final _notifications = FlutterLocalNotificationsPlugin();
  final Set<String> _triggered = {};

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _notifications.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _check();
  }

  Future<void> _check() async {
    Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    // Steps explored: accumulate GPS movement (the active-tour screen counts
    // its own while 'tour_active' is set, so we skip to avoid double counts).
    if (!(prefs.getBool('tour_active') ?? false)) {
      final lastLat = prefs.getDouble('step_last_lat');
      final lastLng = prefs.getDouble('step_last_lng');
      if (lastLat != null && lastLng != null) {
        final d = Geolocator.distanceBetween(
            lastLat, lastLng, pos.latitude, pos.longitude);
        // 3–300 m per 12 s tick = plausible on foot; larger = vehicle/jump.
        if (d >= 3 && d <= 300) {
          const mPerStep = 0.75;
          const totalKey = 'steps_total_m';
          final n = DateTime.now();
          final dayKey = 'steps_day_m_${n.year}-${n.month}-${n.day}';
          await prefs.setDouble(
              totalKey, (prefs.getDouble(totalKey) ?? 0) + d);
          await prefs.setDouble(
              dayKey, (prefs.getDouble(dayKey) ?? 0) + d);
          // ignore: unused_local_variable
          const _ = mPerStep;
        }
      }
      await prefs.setDouble('step_last_lat', pos.latitude);
      await prefs.setDouble('step_last_lng', pos.longitude);
    }

    final interests =
        (prefs.getStringList(kInterests) ?? _defaultInterests).toSet();

    final hotspots = _decode(prefs.getString(kFgHotspots));
    final deals = _decode(prefs.getString(kFgDeals));

    // Report live presence (best-effort), including today's step count so
    // merchants can size a "they have walked a lot today" audience.
    _reportPresence(prefs, pos, _stepsToday(prefs));

    // Greet the user when they arrive in a new city.
    await _checkCityArrival(prefs, pos);

    // On an active tour the tour screen owns arrivals — muting the regular
    // hotspot/deal pings keeps the experience focused (city welcome stays).
    final tourActive = prefs.getBool('tour_active') ?? false;

    for (final h in hotspots) {
      if (tourActive) break;
      final category = h['category'] as String? ?? 'history';
      if (!interests.contains(category)) continue;
      _maybeFire(
        pos,
        id: 'h_${h['id']}',
        lat: (h['lat'] as num).toDouble(),
        lng: (h['lng'] as num).toDouble(),
        radius: (h['radius'] as num).toDouble(),
        title: '${_ntr(prefs, 'now_at')} ${h['name']}',
        body: _ntr(prefs, 'tap_story'),
        category: category,
        payload: 'hotspot:${h['id']}',
        image: h['image'] as String?,
      );
    }

    if (interests.contains('hotdeal')) {
      final userKey = prefs.getString('anon_install_id');
      final steps = _stepsToday(prefs);
      for (final d in deals) {
        if (!_dealTargetsMe(d,
            steps: steps,
            onTour: tourActive,
            interests: interests,
            arrivedAtMs: prefs.getInt('city_arrived_at'))) continue;
        final code = d['code'] as String?;
        final fired = _maybeFire(
          pos,
          id: 'd_${d['id']}',
          lat: (d['lat'] as num).toDouble(),
          lng: (d['lng'] as num).toDouble(),
          radius: (d['radius'] as num).toDouble(),
          title: '🔥 ${d['business']}',
          body: code != null && code.isNotEmpty
              ? '${d['offer']} — CODE: $code'
              : d['offer'] as String,
          category: 'hotdeal',
          redeemCode: code,
          payload: 'deal:${d['id']}',
        );
        // Billable reach: one row per person per deal per day (server-side
        // dedupe), which is what the merchant is charged for.
        if (fired && userKey != null) {
          _logReach(d['id'] as String, userKey);
        }
      }
    }
  }

  /// Does this deal's targeting match me right now? Everything is decided on
  /// the device — the merchant only ever chose the segment, never the person.
  bool _dealTargetsMe(Map<String, dynamic> d,
      {required int steps,
      required bool onTour,
      required Set<String> interests,
      required int? arrivedAtMs}) {
    if (steps < ((d['min_steps'] as num?)?.toInt() ?? 0)) return false;

    final onTourRule = (d['on_tour'] as String?) ?? 'exclude';
    if (onTourRule == 'exclude' && onTour) return false;
    if (onTourRule == 'only' && !onTour) return false;

    final now = DateTime.now();
    final days = (d['days'] as List?)?.map((e) => (e as num).toInt()).toList();
    if (days != null && days.isNotEmpty) {
      // Dart: Monday = 1 … Sunday = 7. Admin/Postgres: Sunday = 0 … Saturday = 6.
      final dow = now.weekday == 7 ? 0 : now.weekday;
      if (!days.contains(dow)) return false;
    }

    final from = (d['hour_from'] as num?)?.toInt() ?? 0;
    final to = (d['hour_to'] as num?)?.toInt() ?? 24;
    if (now.hour < from || now.hour >= to) return false;

    // "Just arrived in town" — within 24 h of the city welcome.
    if ((d['arrival'] as String?) == 'new') {
      if (arrivedAtMs == null) return false;
      final hours = (now.millisecondsSinceEpoch - arrivedAtMs) / 3600000;
      if (hours > 24) return false;
    }

    final interest = d['interest'] as String?;
    if (interest != null && interest.isNotEmpty && !interests.contains(interest)) {
      return false;
    }

    return true;
  }

  Future<void> _logReach(String dealId, String userKey) async {
    try {
      await http.post(
        Uri.parse('$_supabaseUrl/rest/v1/rpc/deal_reach_log'),
        headers: {
          'apikey': _anonKey,
          'Authorization': 'Bearer $_anonKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'p_deal_id': dealId, 'p_user_key': userKey}),
      );
    } catch (_) {}
  }

  // Fire a one-time "Welcome to <city>" notification when the user enters the
  // radius of a published city different from the one we last greeted them in.
  Future<void> _checkCityArrival(SharedPreferences prefs, Position pos) async {
    final cities = _decode(prefs.getString(kFgCities));
    if (cities.isEmpty) return;

    // Nearest city whose welcome radius currently contains the user.
    Map<String, dynamic>? here;
    double best = double.infinity;
    for (final c in cities) {
      final lat = (c['lat'] as num?)?.toDouble();
      final lng = (c['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      final d = Geolocator.distanceBetween(
          pos.latitude, pos.longitude, lat, lng);
      final radiusM = ((c['radius_km'] as num?)?.toDouble() ?? 30) * 1000;
      if (d <= radiusM && d < best) {
        best = d;
        here = c;
      }
    }
    if (here == null) return;

    final cityId = here['id'] as String;
    final last = prefs.getString(kFgLastCity);
    if (cityId == last) return; // already greeted for this stay.

    await prefs.setString(kFgLastCity, cityId);
    // Stamp the arrival so "just arrived" deal targeting can use it.
    await prefs.setInt('city_arrived_at', DateTime.now().millisecondsSinceEpoch);
    final name = here['city'] as String? ?? 'a new city';
    final title = '${_ntr(prefs, 'welcome')} $name 👋';
    final sub = _ntr(prefs, 'welcome_sub');
    _show(title, sub, ('city_$cityId').hashCode, 'city:$cityId');
    _appendLog(title, sub, 'city', null, cityId);
  }

  // Push live position + status to the admin map via the record_presence RPC.
  /// Steps walked today, from the metres the app has accumulated.
  int _stepsToday(SharedPreferences prefs) {
    final n = DateTime.now();
    final m = prefs.getDouble('steps_day_m_${n.year}-${n.month}-${n.day}') ?? 0;
    return (m / 0.75).round();
  }

  Future<void> _reportPresence(
      SharedPreferences prefs, Position pos, int steps) async {
    final sessionId = prefs.getString('anon_install_id');
    if (sessionId == null) return;
    final userId = prefs.getString('presence_user_id');
    final label = prefs.getString('presence_label') ?? 'Guest';
    try {
      await http.post(
        Uri.parse('$_supabaseUrl/rest/v1/rpc/record_presence'),
        headers: {
          'apikey': _anonKey,
          'Authorization': 'Bearer $_anonKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'p_session_id': sessionId,
          'p_user_id': userId,
          'p_label': label,
          'p_is_user': userId != null,
          'p_lat': pos.latitude,
          'p_lng': pos.longitude,
          'p_status': 'exploring',
          'p_status_detail': null,
          'p_steps': steps,
        }),
      );
    } catch (_) {}
  }

  /// Returns true when a notification was actually shown this tick.
  bool _maybeFire(
    Position pos, {
    required String id,
    required double lat,
    required double lng,
    required double radius,
    required String title,
    required String body,
    required String category,
    String? redeemCode,
    required String payload,
    String? image,
  }) {
    if (_triggered.contains(id)) {
      // Re-arm once the user leaves the zone (with a small buffer).
      final d = Geolocator.distanceBetween(pos.latitude, pos.longitude, lat, lng);
      if (d > radius + 30) _triggered.remove(id);
      return false;
    }
    final distance =
        Geolocator.distanceBetween(pos.latitude, pos.longitude, lat, lng);
    if (distance > radius) return false;

    _triggered.add(id);
    _show(title, body, id.hashCode, payload, image: image);
    // payload is "<type>:<targetId>"
    final targetId = payload.contains(':') ? payload.split(':')[1] : null;
    _appendLog(title, body, category, redeemCode, targetId, image: image);
    return true;
  }

  /// Download the hotspot image so the system notification can show it.
  Future<String?> _fetchImageFile(String url, int id) async {
    try {
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/notif_$id.jpg');
      await f.writeAsBytes(res.bodyBytes);
      return f.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _show(String title, String body, int id, String payload,
      {String? image}) async {
    String? imgPath;
    if (image != null && image.isNotEmpty) {
      imgPath = await _fetchImageFile(image, id);
    }
    final android = AndroidNotificationDetails(
      'hotspot_channel',
      'Hotspot Alerts',
      channelDescription: 'Alerts when you are near a historic site',
      importance: Importance.high,
      priority: Priority.high,
      color: const Color(0xFFFFC107),
      colorized: true,
      largeIcon: imgPath != null
          ? FilePathAndroidBitmap(imgPath)
          : DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: imgPath != null
          ? BigPictureStyleInformation(FilePathAndroidBitmap(imgPath),
              hideExpandedLargeIcon: true)
          : null,
    );
    await _notifications.show(
      id,
      title,
      body,
      NotificationDetails(android: android, iOS: const DarwinNotificationDetails()),
      payload: payload,
    );
  }

  Future<void> _appendLog(String title, String body, String category,
      String? code, String? targetId, {String? image}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(kNotificationLog) ?? [];
    raw.insert(
      0,
      jsonEncode({
        'type': category == 'hotdeal'
            ? 'deal'
            : category == 'city'
                ? 'city'
                : 'hotspot',
        'title': title,
        'body': body,
        'category': category,
        'redeem_code': code,
        'target_id': targetId,
        'image': image,
        'at': DateTime.now().toIso8601String(),
      }),
    );
    if (raw.length > 20) raw.removeRange(20, raw.length);
    await prefs.setStringList(kNotificationLog, raw);
  }

  List<Map<String, dynamic>> _decode(String? s) {
    if (s == null || s.isEmpty) return const [];
    try {
      return (jsonDecode(s) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {}

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }
}
