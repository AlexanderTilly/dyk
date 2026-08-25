import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One entry in the local notification history shown on the Explore tab.
class LoggedNotification {
  final String type; // 'hotspot' | 'deal'
  final String title;
  final String body;
  final String? category;
  final String? redeemCode;
  final String? targetId; // hotspot/deal id, for tap-to-open
  final String? imageUrl; // hotspot's first image, for the card thumbnail
  final DateTime at;

  LoggedNotification({
    required this.type,
    required this.title,
    required this.body,
    this.category,
    this.redeemCode,
    this.targetId,
    this.imageUrl,
    required this.at,
  });

  // Payload for NotificationRouter, e.g. "hotspot:<id>".
  String? get payload => targetId == null ? null : '$type:$targetId';

  Map<String, dynamic> toJson() => {
        'type': type,
        'title': title,
        'body': body,
        'category': category,
        'redeem_code': redeemCode,
        'target_id': targetId,
        'image': imageUrl,
        'at': at.toIso8601String(),
      };

  factory LoggedNotification.fromJson(Map<String, dynamic> json) =>
      LoggedNotification(
        type: json['type'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        category: json['category'] as String?,
        redeemCode: json['redeem_code'] as String?,
        targetId: json['target_id'] as String?,
        imageUrl: json['image'] as String?,
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

  /// Pull fresh data written by the background service isolate.
  Future<void> refresh() => _prefs.reload();

  Future<void> add(LoggedNotification entry) async {
    final raw = _prefs.getStringList(_key) ?? [];
    raw.insert(0, jsonEncode(entry.toJson()));
    if (raw.length > _max) raw.removeRange(_max, raw.length);
    await _prefs.setStringList(_key, raw);
  }

  /// Remove all entries (the "Rensa" button on the Notifications page).
  Future<void> clear() async {
    await _prefs.remove(_key);
  }

  /// Remove a single entry (e.g. swiped away on the Explore tab).
  Future<void> removeAt(int index) async {
    final raw = _prefs.getStringList(_key) ?? [];
    if (index < 0 || index >= raw.length) return;
    raw.removeAt(index);
    await _prefs.setStringList(_key, raw);
  }
}
