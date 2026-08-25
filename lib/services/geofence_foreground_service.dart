import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/hot_deal.dart';
import '../models/hotspot.dart';
import 'geofence_task_handler.dart';

/// Controls the background foreground-service that powers geofencing while
/// the app is backgrounded. Keeps a persistent notification alive (Android
/// requirement) and the geofence checks running in a separate isolate.
class GeofenceForegroundService {
  bool _initialized = false;

  void init() {
    if (_initialized) return;
    _initialized = true;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'dyk_exploring',
        channelName: 'DYK Exploring',
        channelDescription: 'Active while discovering places near you',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(12000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  // Interests are read by the handler straight from AppState's own pref key,
  // so we only persist the geofence geometry here.
  Future<void> _writeData(
      List<Hotspot> hotspots, List<HotDeal> deals) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      kFgHotspots,
      jsonEncode(hotspots
          .map((h) => {
                'id': h.id,
                'name': h.name,
                'lat': h.lat,
                'lng': h.lng,
                'radius': h.radiusMeters,
                'category': h.category,
                'image': h.images.isNotEmpty ? h.images.first : null,
              })
          .toList()),
    );
    await prefs.setString(
      kFgDeals,
      jsonEncode(deals
          .map((d) => {
                'id': d.id,
                'business': d.businessName,
                'offer': d.offerText,
                'code': d.redeemCode,
                'lat': d.lat,
                'lng': d.lng,
                'radius': d.radiusMeters,
                // Targeting rules the background isolate evaluates locally.
                'min_steps': d.minStepsToday,
                'on_tour': d.targetOnTour,
                'days': d.activeDays,
                'hour_from': d.activeHourFrom,
                'hour_to': d.activeHourTo,
                'arrival': d.targetArrival,
                'interest': d.targetInterest,
              })
          .toList()),
    );
  }

  Future<void> start({
    required List<Hotspot> hotspots,
    required List<HotDeal> deals,
    Set<String> interests = const {},
  }) async {
    init();
    await _writeData(hotspots, deals);

    // A location-typed foreground service requires the "Allow all the time"
    // (background location) grant on Android 10+. Starting it without that
    // throws and crashes the app on Android 14, so only start when granted.
    // Without it the app still works in the foreground; the service starts
    // automatically next time once the user enables background location.
    if (!await Permission.locationAlways.isGranted) {
      debugPrint('GeofenceForegroundService: background location not granted '
          '— skipping foreground service start.');
      return;
    }

    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.restartService();
        return;
      }

      await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: '🧭 DYK is exploring',
        notificationText: 'Discovering places near you — tap to open',
        callback: startGeofenceCallback,
      );
    } catch (e) {
      // Never let a platform/permission error crash the app.
      debugPrint('GeofenceForegroundService.start failed: $e');
    }
  }

  /// Update geofence data/interests without restarting (cheap — handler
  /// re-reads prefs every tick).
  Future<void> update({
    required List<Hotspot> hotspots,
    required List<HotDeal> deals,
    Set<String> interests = const {},
  }) async {
    await _writeData(hotspots, deals);
  }

  Future<void> stop() async {
    await FlutterForegroundTask.stopService();
  }
}
