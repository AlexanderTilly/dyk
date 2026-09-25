import 'package:shared_preferences/shared_preferences.dart';

import '../models/support_ticket.dart';

/// Tickets whose newest message is a staff reply newer than the watermark.
/// Pure so it can be unit-tested; the Android isolate mirrors this rule.
List<SupportTicketSummary> unseenTickets(
  List<SupportTicketSummary> tickets,
  Map<String, DateTime> watermarks,
) {
  return tickets.where((t) {
    if (t.lastFromCustomer) return false;
    final mark = watermarks[t.id];
    return mark == null || t.lastAt.isAfter(mark);
  }).toList();
}

/// Per-ticket "seen" (user opened the thread) and "notified" (we showed a
/// notification) marks in SharedPreferences. Values are UTC ISO-8601 so the
/// Android isolate, which reads the same keys with plain string parsing,
/// agrees with the app.
class SupportSeenStore {
  final SharedPreferences _prefs;
  SupportSeenStore(this._prefs);

  static Future<SupportSeenStore> load() async =>
      SupportSeenStore(await SharedPreferences.getInstance());

  /// Forces a resync with the platform store. Needed before reading
  /// watermarks that may have been written by a different isolate (the
  /// Android foreground service) since this store was created —
  /// SharedPreferences caches in memory per isolate and does not see
  /// another isolate's writes without this.
  Future<void> reload() => _prefs.reload();

  static String seenKey(String id) => 'support_seen_$id';
  static String notifiedKey(String id) => 'support_notified_$id';

  DateTime? _read(String key) {
    final v = _prefs.getString(key);
    return v == null ? null : DateTime.parse(v).toUtc();
  }

  /// max(seen, notified) per ticket — the bar a reply must clear to be
  /// worth a notification.
  Map<String, DateTime> watermarks(Iterable<String> ticketIds) {
    final out = <String, DateTime>{};
    for (final id in ticketIds) {
      final seen = _read(seenKey(id));
      final notified = _read(notifiedKey(id));
      final mark = [seen, notified].whereType<DateTime>().fold<DateTime?>(
          null, (best, d) => best == null || d.isAfter(best) ? d : best);
      if (mark != null) out[id] = mark;
    }
    return out;
  }

  Future<void> markSeen(String ticketId, DateTime at) =>
      _prefs.setString(seenKey(ticketId), at.toUtc().toIso8601String());

  Future<void> markNotified(String ticketId, DateTime at) =>
      _prefs.setString(notifiedKey(ticketId), at.toUtc().toIso8601String());

  /// For the unread dot: a staff reply the user has not opened yet.
  bool isUnseen(SupportTicketSummary t) {
    if (t.lastFromCustomer) return false;
    final seen = _read(seenKey(t.id));
    return seen == null || t.lastAt.isAfter(seen);
  }
}
