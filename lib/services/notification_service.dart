import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_router.dart';

// Shared DYK branding for notifications: yellow accent + logo large icon.
const dykNotificationColor = Color(0xFFFFC107);
final dykLargeIcon = DrawableResourceAndroidBitmap('@mipmap/ic_launcher');

// Must be a top-level function for background notification taps.
@pragma('vm:entry-point')
void notificationBackgroundTap(NotificationResponse response) {
  NotificationRouter.handlePayload(response.payload);
}

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin;

  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    // iOS has no separate settings-screen toggle: if we never ask here, the
    // app can never show a notification. Android ignores these flags.
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (resp) =>
          NotificationRouter.handlePayload(resp.payload),
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundTap,
    );

    // If the app was launched by tapping a notification (cold start),
    // route to it once the UI is ready.
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      NotificationRouter.handlePayload(launch!.notificationResponse?.payload);
    }

    // Create channels up front so the app shows up in Android's
    // notification settings before the first notification fires.
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          'hotspot_channel',
          'Hotspot Alerts',
          description: 'Alerts when you are near a historic site',
          importance: Importance.high,
        ),
      );
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          'deal_channel',
          'Hot Deals',
          description: 'Local offers near you',
          importance: Importance.high,
        ),
      );
    }
  }

  Future<void> showHotspotNotification({
    required String hotspotId,
    required String name,
    required int year,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'hotspot_channel',
      'Hotspot Alerts',
      channelDescription: 'Alerts when you are near a historic site',
      importance: Importance.high,
      priority: Priority.high,
      color: dykNotificationColor,
      colorized: true,
      largeIcon: dykLargeIcon,
    );
    const iosDetails = DarwinNotificationDetails();
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      hotspotId.hashCode,
      'You are now at $name',
      'Founded $year — tap to hear the story',
      details,
      payload: 'hotspot:$hotspotId',
    );
  }

  Future<void> showDealNotification({
    required String dealId,
    required String businessName,
    required String offerText,
    String? redeemCode,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'deal_channel',
      'Hot Deals',
      channelDescription: 'Local offers near you',
      importance: Importance.high,
      priority: Priority.high,
      color: dykNotificationColor,
      colorized: true,
      largeIcon: dykLargeIcon,
    );
    const iosDetails = DarwinNotificationDetails();
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final body = redeemCode != null && redeemCode.isNotEmpty
        ? '$offerText — CODE: $redeemCode'
        : offerText;

    await _plugin.show(
      dealId.hashCode,
      '🔥 $businessName',
      body,
      details,
      payload: 'deal:$dealId',
    );
  }
}
