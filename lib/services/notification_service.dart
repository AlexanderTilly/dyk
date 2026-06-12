import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin;

  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _plugin.initialize(settings);

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
    const androidDetails = AndroidNotificationDetails(
      'hotspot_channel',
      'Hotspot Alerts',
      channelDescription: 'Alerts when you are near a historic site',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      hotspotId.hashCode,
      'You are now at $name',
      'Founded $year — tap to hear the story',
      details,
      payload: hotspotId,
    );
  }

  Future<void> showDealNotification({
    required String dealId,
    required String businessName,
    required String offerText,
    String? redeemCode,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'deal_channel',
      'Hot Deals',
      channelDescription: 'Local offers near you',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
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
      payload: 'deal_$dealId',
    );
  }
}
