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
  }

  Future<void> showHotspotNotification({
    required String hotspotId,
    required String name,
    required int year,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'hotspot_channel',
      'Hotspot Alerts',
      channelDescription: 'Notiser när du är nära en historisk plats',
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
      'Du står nu vid $name',
      'Grundad $year — tryck för att höra historien',
      details,
      payload: hotspotId,
    );
  }
}
