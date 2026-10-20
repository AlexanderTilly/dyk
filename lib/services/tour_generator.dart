import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../models/tour.dart';

/// How long one generate-tour request may run before it is abandoned.
///
/// Load-bearing: the generator screen releases its lever latch after
/// `pullTimeout` (30 s) as a backstop. This must stay BELOW that, or the lever
/// looks dead before the network has given up. Tune one, tune the other.
/// Every request is capped because narration requests spun for minutes on
/// 2026-09-30 when nothing capped them.
const tourRequestTimeout = Duration(seconds: 25);

/// Cap on a whole pull in the UI: locate, read prefs, request. Above the
/// request's 25 s, below the screen's 30 s latch, so the parent's busy flag is
/// always cleared before the screen gives up on it.
const tourRunTimeout = Duration(seconds: 28);

/// The generator found too few places for this theme near the start.
/// The remedy is to turn a wheel, so the screen shows this at the theme reel.
class TourTooFew implements Exception {
  final String theme;
  const TourTooFew(this.theme);
  @override
  String toString() => 'TourTooFew($theme)';
}

/// Anything else that stops a round: network, timeout, server or bad reply.
class TourGenerationFailed implements Exception {
  final String reason;

  /// No connectivity (as opposed to a slow or failing server). The one failure
  /// worth its own message: it is the most common one for a tourist, and
  /// "you are offline" is something they can act on.
  final bool offline;
  const TourGenerationFailed(this.reason, {this.offline = false});
  @override
  String toString() => 'TourGenerationFailed($reason)';
}

class GeneratedStop {
  final int orderIndex;
  final String hotspotId;
  final String title;
  final double lat;
  final double lng;
  const GeneratedStop({
    required this.orderIndex,
    required this.hotspotId,
    required this.title,
    required this.lat,
    required this.lng,
  });
}

class GeneratedTour {
  final String tourId;
  final String title;

  /// The MEASURED route length. Show this, never the asked-for distance: a
  /// "2 km" pull may come back at 1.76 km.
  final int meters;
  final int minutes;
  final List<GeneratedStop> stops;
  final Map<String, dynamic>? geojson;

  const GeneratedTour({
    required this.tourId,
    required this.title,
    required this.meters,
    required this.minutes,
    required this.stops,
    this.geojson,
  });

  List<String> get placeIds => [for (final s in stops) s.hotspotId];

  /// The tour as the existing detail screen wants it. Generated tours are
  /// unpublished; the detail screen reads the stops from the database (RLS
  /// from migration 050).
  Tour toTour(String citypackId) => Tour(
        id: tourId,
        citypackId: citypackId,
        type: 'custom',
        title: title,
        distanceMeters: meters,
        estMinutes: minutes,
        routeGeojson: geojson,
      );

  factory GeneratedTour.fromJson(Map<String, dynamic> j) {
    if ((j['stops'] as List).isEmpty) {
      // A tour with no stops is the blank-tour outcome migration 050 exists
      // to prevent; never hand it to the detail screen.
      throw const FormatException('tour has no stops');
    }
    final stops = [
      for (final s in (j['stops'] as List))
        GeneratedStop(
          orderIndex: (s['order_index'] as num).toInt(),
          hotspotId: s['hotspot_id'] as String,
          title: (s['title'] as String?) ?? '',
          lat: (s['lat'] as num).toDouble(),
          lng: (s['lng'] as num).toDouble(),
        )
    ]..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return GeneratedTour(
      tourId: j['tour_id'] as String,
      title: j['title'] as String,
      meters: (j['meters'] as num).round(),
      minutes: (j['minutes'] as num).round(),
      stops: stops,
      geojson: j['geojson'] as Map<String, dynamic>?,
    );
  }
}

/// The places of the last few rounds, to steer the next pull elsewhere.
///
/// Bounded on purpose. An ever-growing exclude list starves the pool: measured,
/// rounds shrank from 8 stops to 3, handing someone who asked for 3 km a stub.
/// The server also truncates (to the last 8 ids); this bound is belt and
/// braces and keeps requests small.
class ExcludeHistory {
  /// Only this many previous rounds are remembered.
  static const maxRounds = 2;

  final List<List<String>> _rounds = [];

  void add(List<String> placeIds) {
    _rounds.add(List.of(placeIds));
    while (_rounds.length > maxRounds) {
      _rounds.removeAt(0);
    }
  }

  List<String> get ids => {for (final r in _rounds) ...r}.toList();
}

/// Calls the `generate-tour` edge function. Direct HTTP with an explicit
/// timeout, not the client's generic invoke helper, so a hung request cannot
/// outlive [timeout].
class TourGenerator {
  final http.Client _client;
  final String _baseUrl;
  final String _anonKey;
  final Duration _timeout;

  TourGenerator({
    required http.Client client,
    required String baseUrl,
    required String anonKey,
    Duration timeout = tourRequestTimeout,
  })  : _client = client,
        _baseUrl = baseUrl,
        _anonKey = anonKey,
        _timeout = timeout;

  Future<GeneratedTour> generate({
    required double lat,
    required double lng,
    required int km,
    required String shape,
    required String theme,
    required String citypackId,
    List<String> exclude = const [],
    String? installId,
  }) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$_baseUrl/functions/v1/generate-tour'),
            headers: {
              'Content-Type': 'application/json',
              'apikey': _anonKey,
              'Authorization': 'Bearer $_anonKey',
            },
            body: jsonEncode({
              'lat': lat,
              'lng': lng,
              'km': km,
              'shape': shape,
              'theme': theme,
              'citypack_id': citypackId,
              'exclude': exclude,
              if (installId != null) 'install_id': installId,
            }),
          )
          .timeout(_timeout);
      if (res.statusCode == 422) throw TourTooFew(theme);
      if (res.statusCode != 200) {
        throw TourGenerationFailed('HTTP ${res.statusCode}');
      }
      return GeneratedTour.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
    } on TourTooFew {
      rethrow;
    } on TimeoutException {
      throw const TourGenerationFailed('timeout');
    } on TourGenerationFailed {
      rethrow;
    } catch (e) {
      // http's IOClient wraps a SocketException in a ClientException.
      final offline = e is SocketException ||
          (e is http.ClientException && e.message.contains('SocketException'));
      throw TourGenerationFailed('$e', offline: offline);
    }
  }
}

/// Why the phone gave no usable position.
enum LocationIssue { denied, disabled, timeout }

/// The phone's position, or why there is none.
class TourLocation {
  final ({double lat, double lng})? fix;
  final LocationIssue? issue;
  const TourLocation(this.fix, [this.issue]);

  /// Permission refused or location switched off: the person should be told
  /// the round starts from the city centre. A mere timeout is not worth a
  /// notice (location works, it was just slow).
  bool get needsNotice =>
      issue == LocationIssue.denied || issue == LocationIssue.disabled;
}

/// Beyond this from the city centre, the phone's position is not a usable
/// start for a round.
const tourStartMaxKm = 30;

/// Where a round starts. [gps] is the phone's fix (null if it failed) and
/// [centre] the city pack's centre (null if unknown).
///
/// A tourist planning a trip from home, or testing from another country, has a
/// perfectly good fix that is nowhere near the city. Starting there makes the
/// server find nothing and answer "too few", which the app would show as "not
/// enough places for that theme" - false, the places exist, just far away. So
/// a fix farther than [tourStartMaxKm] from the centre is replaced by it.
({double lat, double lng})? chooseTourStart(
  ({double lat, double lng})? gps,
  ({double lat, double lng})? centre, {
  double Function(double, double, double, double) distanceMeters =
      Geolocator.distanceBetween,
}) {
  if (gps == null) return centre;
  if (centre == null) return gps;
  final d = distanceMeters(gps.lat, gps.lng, centre.lat, centre.lng);
  return d > tourStartMaxKm * 1000 ? centre : gps;
}
