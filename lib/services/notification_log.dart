import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One entry in the local notification history shown on the Explore tab.
class LoggedNotification {
  final String type; // 'hotspot' | 'deal'
  final String title;
  final String body;
  final String? category;
  final String? redeemCode;
  final DateTime at;

  LoggedNotification({
    required this.type,
    required this.title,
    required this.body,
    this.category,
    this.redeemCode,
    required this.at,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'title': title,
        'body': body,
        'category': category,
        'redeem_code': redeemCode,
        'at': at.toIso8601String(),
      };

  factory LoggedNotification.fromJson(Map<String, dynamic> json) =>
      LoggedNotification(
        type: json['type'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        category: json['category'] as String?,
        redeemCode: json['redeem_code'] as String?,
        at: DateTime.parse(json['at'] as String),
      );
}

class NotificationLog {
  static const _key = 'notification_log';
  static const _max = 20;
  final SharedPreferences _prefs;

  NotificationLog(this._prefs);

  List<LoggedNotification> get entries {
    final raw = _prefs.getStringList(_key) ?? [];
    return raw
        .map((s) =>
            LoggedNotification.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> add(LoggedNotification entry) async {
    final raw = _prefs.getStringList(_key) ?? [];
    raw.insert(0, jsonEncode(entry.toJson()));
    if (raw.length > _max) raw.removeRange(_max, raw.length);
    await _prefs.setStringList(_key, raw);
  }
}
