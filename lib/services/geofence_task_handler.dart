import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/dyk_theme.dart';

const _supabaseUrl = 'https://jqykkyhoxpykhixwgwyw.supabase.co';
const _anonKey = 'sb_publishable_HCRDnKdePmnT0ukTyVlFCg_q0MRPyhK';

// Keys shared between the UI isolate and the background service isolate.
const kFgHotspots = 'fg_hotspots';
const kFgDeals = 'fg_deals';
const kFgEvents = 'fg_events';
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
    'support_reply_title': 'Passim Support replied',
  },
  'es': {
    'now_at': 'Estás en',
    'tap_story': 'Toca para escuchar la historia',
    'welcome': 'Bienvenido a',
    'welcome_sub': 'Toca para descubrir sus historias, mitos y joyas ocultas.',
    'support_reply_title': 'Soporte de Passim ha respondido',
  },
  'ca': {
    'now_at': 'Ets a',
    'tap_story': 'Toca per escoltar la història',
    'welcome': 'Benvingut a',
    'welcome_sub': 'Toca per descobrir històries, mites i racons amagats.',
    'support_reply_title': 'Suport de Passim ha respost',
  },
  'de': {
    'now_at': 'Du bist jetzt an:',
    'tap_story': 'Tippe, um die Geschichte zu hören',
    'welcome': 'Willkommen in',
    'welcome_sub': 'Tippe für Geschichten, Mythen & versteckte Schätze.',
    'support_reply_title': 'Passim Support hat geantwortet',
  },
};

String _ntr(SharedPreferences prefs, String key) {
  final lang = prefs.getString('app_lang') ?? 'en';
  return _notifStrings[lang]?[key] ?? _notifStrings['en']![key]!;
}

// ---------------------------------------------------------------------------
// Adaptive location cadence — pure logic, unit-tested in
// test/services/geofence_cadence_test.dart.
//
// RULE: accuracy and frequency may relax only where relaxing them cannot cost
// an arrival. Everything below is derived from that, not tuned by feel.
//
// DERIVATION
//  * The foreground-task heartbeat stays at 12 s (see the service). It is only
//    a timer. What costs power is the GPS fix, so the handler decides per
//    heartbeat whether to take one.
//  * Speed bound  v = 3.0 m/s. A brisk walk is ~1.4 m/s; 3 m/s is a jog and
//    already 2x any tourist on foot. If the last two fixes show the phone
//    moving faster (bike, scooter, car) the bound becomes 1.5x the observed
//    speed (cap 40 m/s), so a vehicle shortens the interval instead of
//    outrunning it.
//  * Position error  e = max(1.5 x reported accuracy, 100 m). 100 m is the
//    floor of geolocator's documented 'medium' class (100-500 m); a fix that
//    reports itself worse than that is believed.
//  * Edge distance  d = distance to the circle's rim; a user is "in" at
//    d <= 0. The worst-case true distance to the rim is d - e.
//  * Guard  g = 150 m. Whenever we are about to switch to a coarse fix we make
//    sure the user cannot be closer than g to any rim at the next fix. g is
//    four near-ticks of walking at v (4 x 12 s x 3 m/s = 144 m), so the near
//    regime always has several high-accuracy ticks before a rim can be reached,
//    and a coarse fix that misreads the position by up to its own error can
//    still not hide an arrival.
//  * Far interval  T = (d - e - g) / v, so at the next fix the user is at best
//    g from the rim. If T would be under one heartbeat (d - e < g + 12 v) the
//    user is NEAR: 12 s, high accuracy, exactly the old behaviour.
//  * Stillness and the clock only ever raise the *cap* on T, never T itself.
//    So no stillness heuristic, however wrong, can let a walker reach a rim
//    unobserved. This also means that near a zone a resting phone keeps the
//    12 s cadence: without a motion sensor (none is a dependency) a position
//    fix is the only way to notice the owner standing up, and waiting for one
//    would cost the first arrival after the café.
// ---------------------------------------------------------------------------

/// Heartbeat of the foreground task and the near-regime fix cadence.
const kHeartbeat = Duration(seconds: 12);

/// Planning speed for a person on foot (m/s). See derivation above.
const kWalkBoundMps = 3.0;

/// Never plan on a vehicle faster than this (m/s).
const kMaxBoundMps = 40.0;

/// Floor for position error when planning (m).
const kErrorFloorM = 100.0;

/// Distance from a rim we always want to be able to re-arm high accuracy in (m).
const kGuardM = 150.0;

/// Longest gap between fixes for a moving phone that is far from everything.
const kFarCap = Duration(minutes: 3);

/// Longest gap once the phone has not left a ~60 m circle for [kStillAfter].
const kStillCap = Duration(minutes: 10);

/// ... and also between 01:00 and 06:00 local time.
const kNightCap = Duration(minutes: 20);

/// How long a phone must stay inside [kStillRadiusM] to count as resting.
/// A café table is longer than this; a plaque read in a pocket is not.
const kStillAfter = Duration(minutes: 20);

/// Jitter allowance for the stillness circle (m).
const kStillRadiusM = 60.0;

/// A circle the user can arrive in. [fine] false = a city welcome radius,
/// where a coarse fix is plenty.
class FenceCircle {
  final double lat;
  final double lng;
  final double radiusM;
  final bool fine;
  const FenceCircle(this.lat, this.lng, this.radiusM, {this.fine = true});
}

enum PollRegime { near, far, rest }

class PollPlan {
  /// Minimum time before the next fix. For [PollRegime.near] this is one
  /// heartbeat, i.e. take a fix on every heartbeat as before.
  final Duration interval;
  final LocationAccuracy accuracy;
  final PollRegime regime;
  const PollPlan(this.interval, this.accuracy, this.regime);

  @override
  String toString() => 'PollPlan($regime, ${interval.inSeconds}s, $accuracy)';
}

const _nearPlan = PollPlan(kHeartbeat, LocationAccuracy.high, PollRegime.near);

double _haversineM(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.min(1.0, math.sqrt(a)));
}

/// Decides when and how precisely to take the next fix. Pure: depends only on
/// its arguments.
///
/// [stillFor] is how long the phone has stayed within [kStillRadiusM] of one
/// spot; [observedSpeedMps] is the speed seen between the last two fixes.
PollPlan planNextFix({
  required double lat,
  required double lng,
  required double accuracyM,
  required List<FenceCircle> fences,
  required DateTime now,
  Duration stillFor = Duration.zero,
  double observedSpeedMps = 0,
}) {
  // Nothing to measure against (prefs not written yet, or no content): we
  // cannot prove it is safe to relax, so don't.
  if (fences.isEmpty) return _nearPlan;

  final v = math.min(
      kMaxBoundMps, math.max(kWalkBoundMps, observedSpeedMps * 1.5));
  final e = math.max(accuracyM * 1.5, kErrorFloorM);

  double fineEdge = double.infinity;
  double cityEdge = double.infinity;
  for (final f in fences) {
    final edge = _haversineM(lat, lng, f.lat, f.lng) - f.radiusM;
    if (f.fine) {
      fineEdge = math.min(fineEdge, edge);
    } else {
      cityEdge = math.min(cityEdge, edge);
    }
  }

  final nearBeyond = kGuardM + v * kHeartbeat.inSeconds;
  if (fineEdge - e < nearBeyond) return _nearPlan;

  var seconds = (fineEdge - e - kGuardM) / v;
  // A city welcome fires from any fix inside its radius, so it needs no guard.
  if (cityEdge.isFinite) seconds = math.min(seconds, (cityEdge - e) / v);

  final rested = stillFor >= kStillAfter;
  final night = now.hour >= 1 && now.hour < 6;
  final cap = rested ? (night ? kNightCap : kStillCap) : kFarCap;

  final secs = seconds
      .clamp(kHeartbeat.inSeconds.toDouble(), cap.inSeconds.toDouble())
      .floor();
  return PollPlan(Duration(seconds: secs), LocationAccuracy.medium,
      rested ? PollRegime.rest : PollRegime.far);
}

/// Where the phone has been sitting, and since when.
class StillAnchor {
  final double lat;
  final double lng;
  final DateTime since;
  const StillAnchor(this.lat, this.lng, this.since);
}

/// Folds a fix into the stillness anchor. The anchor stays on the first fix
/// (it does not drift with the phone), so a slow walk eventually leaves the
/// circle. The circle widens with a poor fix so jitter doesn't read as motion.
StillAnchor trackStillness(StillAnchor? prev, double lat, double lng,
    double accuracyM, DateTime now) {
  if (prev == null) return StillAnchor(lat, lng, now);
  final radius = math.max(kStillRadiusM, accuracyM);
  return _haversineM(prev.lat, prev.lng, lat, lng) > radius
      ? StillAnchor(lat, lng, now)
      : prev;
}

/// Metres of walking to credit for a step sample, or 0 to reject it.
///
/// Within a normal tick the rule is the original one (3-300 m). Across a long
/// gap the ceiling grows with time at walking speed — a longer interval must
/// not make a bus ride look like a stroll — and between coarse fixes the
/// floor rises to the combined fix error so a stationary phone's wander is not
/// counted as steps.
double stepMetresToCount({
  required double distanceM,
  required double elapsedSeconds,
  required double accuracyM,
  required double lastAccuracyM,
}) {
  final ceiling = math.max(300.0, kWalkBoundMps * elapsedSeconds);
  final floor = elapsedSeconds <= 30
      ? 3.0
      : math.max(3.0, accuracyM + lastAccuracyM);
  return (distanceM >= floor && distanceM <= ceiling) ? distanceM : 0;
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
  // Support polling runs on the wall clock, independent of how often the
  // location loop decides to take a fix.
  DateTime? _lastSupportAt;
  static const _supportEvery = Duration(minutes: 5);

  // Adaptive cadence state (in memory: a restart simply starts conservative).
  DateTime? _nextFixAt; // null = take a fix on every heartbeat
  LocationAccuracy _accuracy = LocationAccuracy.high;
  StillAnchor? _still;
  double? _prevLat, _prevLng, _prevAcc;
  DateTime? _prevAt;

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
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final now = DateTime.now();
    _lastSupportAt ??= now;
    if (now.difference(_lastSupportAt!) >= _supportEvery) {
      _lastSupportAt = now;
      await _checkSupportReplies(prefs);
    }

    // An active tour keeps today's cadence and accuracy untouched.
    final tourActive = prefs.getBool('tour_active') ?? false;
    final gate = _nextFixAt;
    if (!tourActive && gate != null && now.isBefore(gate)) return;

    Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: tourActive ? LocationAccuracy.high : _accuracy,
      );
    } catch (_) {
      return;
    }

    // Steps explored: accumulate GPS movement (the active-tour screen counts
    // its own while 'tour_active' is set, so we skip to avoid double counts).
    if (!tourActive) {
      final lastLat = prefs.getDouble('step_last_lat');
      final lastLng = prefs.getDouble('step_last_lng');
      if (lastLat != null && lastLng != null) {
        final d = Geolocator.distanceBetween(
            lastLat, lastLng, pos.latitude, pos.longitude);
        // Samples are no longer a fixed 12 s apart, so judge each against the
        // time it actually spans (see stepMetresToCount).
        final lastTs = prefs.getInt('step_last_ts');
        final elapsed = lastTs == null
            ? kHeartbeat.inSeconds.toDouble()
            : (now.millisecondsSinceEpoch - lastTs) / 1000;
        final counted = stepMetresToCount(
          distanceM: d,
          elapsedSeconds: elapsed,
          accuracyM: pos.accuracy,
          lastAccuracyM: prefs.getDouble('step_last_acc') ?? 0,
        );
        if (counted > 0) {
          const totalKey = 'steps_total_m';
          final dayKey = 'steps_day_m_${now.year}-${now.month}-${now.day}';
          await prefs.setDouble(
              totalKey, (prefs.getDouble(totalKey) ?? 0) + counted);
          await prefs.setDouble(
              dayKey, (prefs.getDouble(dayKey) ?? 0) + counted);
        }
      }
      await prefs.setDouble('step_last_lat', pos.latitude);
      await prefs.setDouble('step_last_lng', pos.longitude);
      await prefs.setInt('step_last_ts', now.millisecondsSinceEpoch);
      await prefs.setDouble('step_last_acc', pos.accuracy);
    }

    final interests =
        (prefs.getStringList(kInterests) ?? _defaultInterests).toSet();

    final hotspots = _decode(prefs.getString(kFgHotspots));
    final deals = _decode(prefs.getString(kFgDeals));
    final events = _decode(prefs.getString(kFgEvents));

    // Report live presence (best-effort), including today's step count so
    // merchants can size a "they have walked a lot today" audience.
    _reportPresence(prefs, pos, _stepsToday(prefs));

    // Greet the user when they arrive in a new city.
    await _checkCityArrival(prefs, pos);

    // On an active tour the tour screen owns arrivals — muting the regular
    // hotspot/deal pings keeps the experience focused (city welcome stays).
    // (tourActive was read above.)

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


    // Events ping regardless of interests: a tourist has not opted out of
    // "there is a concert fifty metres away" the way they opt out of a
    // category of story. They are muted on an active tour like everything
    // else, so a guided walk stays a guided walk.
    for (final e in events) {
      if (tourActive) break;
      _maybeFire(
        pos,
        id: 'e_${e['id']}',
        lat: (e['lat'] as num).toDouble(),
        lng: (e['lng'] as num).toDouble(),
        radius: (e['radius'] as num).toDouble(),
        title: e['title'] as String,
        body: (e['subtitle'] as String?)?.isNotEmpty == true
            ? e['subtitle'] as String
            : _ntr(prefs, 'tap_story'),
        category: 'event',
        payload: 'event:${e['id']}',
        image: e['image'] as String?,
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

    _planNext(prefs, pos, now, tourActive, hotspots, deals, events);
  }

  /// Decide when, and how precisely, the next fix is taken (planNextFix).
  /// Every hotspot, deal and event counts as a place the user could arrive —
  /// interests and deal targeting are deliberately not applied, because they
  /// can change between fixes and a superset is the safe side.
  void _planNext(
    SharedPreferences prefs,
    Position pos,
    DateTime now,
    bool tourActive,
    List<Map<String, dynamic>> hotspots,
    List<Map<String, dynamic>> deals,
    List<Map<String, dynamic>> events,
  ) {
    // Speed between the last two fixes, discounting both fixes' error.
    var speed = 0.0;
    if (_prevLat != null && _prevAt != null) {
      final dt = now.difference(_prevAt!).inMilliseconds / 1000;
      if (dt >= 5) {
        final d = Geolocator.distanceBetween(
            _prevLat!, _prevLng!, pos.latitude, pos.longitude);
        speed = math.max(0.0, d - pos.accuracy - (_prevAcc ?? 0)) / dt;
      }
    }
    _prevLat = pos.latitude;
    _prevLng = pos.longitude;
    _prevAcc = pos.accuracy;
    _prevAt = now;
    _still = trackStillness(_still, pos.latitude, pos.longitude, pos.accuracy, now);

    if (tourActive) {
      _nextFixAt = null;
      _accuracy = LocationAccuracy.high;
      return;
    }

    final fences = <FenceCircle>[];
    void add(List<Map<String, dynamic>> src) {
      for (final m in src) {
        final lat = (m['lat'] as num?)?.toDouble();
        final lng = (m['lng'] as num?)?.toDouble();
        final r = (m['radius'] as num?)?.toDouble();
        if (lat == null || lng == null || r == null) continue;
        fences.add(FenceCircle(lat, lng, r));
      }
    }

    add(hotspots);
    add(deals);
    add(events);
    // Cities not yet greeted (the one we are in has just been recorded).
    final lastCity = prefs.getString(kFgLastCity);
    for (final c in _decode(prefs.getString(kFgCities))) {
      if (c['id'] == lastCity) continue;
      final lat = (c['lat'] as num?)?.toDouble();
      final lng = (c['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      final rKm = (c['radius_km'] as num?)?.toDouble() ?? 30;
      fences.add(FenceCircle(lat, lng, rKm * 1000, fine: false));
    }

    final plan = planNextFix(
      lat: pos.latitude,
      lng: pos.longitude,
      accuracyM: pos.accuracy,
      fences: fences,
      now: now,
      stillFor: now.difference(_still!.since),
      observedSpeedMps: speed,
    );
    _accuracy = plan.accuracy;
    // Near = a fix on every heartbeat, exactly as before. Otherwise leave a
    // little slack so heartbeat jitter cannot stretch a gap by a whole beat.
    _nextFixAt = plan.regime == PollRegime.near
        ? null
        : now.add(plan.interval - const Duration(seconds: 2));
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

  /// Mirror of SupportReplyChecker for the background isolate: plain HTTP
  /// against the same RPC, same SharedPreferences keys, same rule — a staff
  /// reply newer than both the seen and the notified mark gets one
  /// notification. Watermarks are UTC ISO-8601, compared as DateTimes.
  Future<void> _checkSupportReplies(SharedPreferences prefs) async {
    final installId = prefs.getString('anon_install_id');
    if (installId == null || installId.length < 8) return;
    try {
      final res = await http.post(
        Uri.parse('$_supabaseUrl/rest/v1/rpc/support_my_tickets'),
        headers: {
          'apikey': _anonKey,
          'Authorization': 'Bearer $_anonKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'p_install_id': installId}),
      );
      if (res.statusCode != 200) return;
      final list = jsonDecode(res.body);
      if (list is! List) return;
      for (final raw in list) {
        final t = raw as Map<String, dynamic>;
        if (t['last_from_customer'] == true) continue;
        final id = t['id'] as String?;
        final lastAtRaw = t['last_at'] as String?;
        if (id == null || lastAtRaw == null) continue;
        final lastAt = DateTime.parse(lastAtRaw).toUtc();
        DateTime? mark(String key) {
          final v = prefs.getString(key);
          return v == null ? null : DateTime.parse(v).toUtc();
        }
        final seen = mark('support_seen_$id');
        final notified = mark('support_notified_$id');
        if (seen != null && !lastAt.isAfter(seen)) continue;
        if (notified != null && !lastAt.isAfter(notified)) continue;
        final body = (t['last_body'] as String?) ?? '';
        await _notifications.show(
          id.hashCode,
          _ntr(prefs, 'support_reply_title'),
          body.length > 80 ? body.substring(0, 80) : body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'support_channel',
              'Support',
              channelDescription: 'Replies from Passim Support',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          payload: 'support:$id',
        );
        await prefs.setString('support_notified_$id', lastAt.toIso8601String());
      }
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
      color: PassimColors.brand,
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
