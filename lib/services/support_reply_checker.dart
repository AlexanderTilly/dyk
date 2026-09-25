import 'support_api.dart';
import 'support_seen_store.dart';

typedef SupportNotify = Future<void> Function({required String ticketId, required String body});

/// Asks the server for the device's tickets and shows one local notification
/// per staff reply the user has neither seen nor been told about. Runs on
/// launch and on every resume; the Android isolate runs the same rule on a
/// timer. Never throws — a failed check just waits for the next one.
class SupportReplyChecker {
  final SupportApi _api;
  final SupportSeenStore _store;
  final Future<String> Function() _installId;
  final SupportNotify _notify;

  static const bodyLimit = 80;

  SupportReplyChecker({
    required SupportApi api,
    required SupportSeenStore store,
    required Future<String> Function() installId,
    required SupportNotify notify,
  })  : _api = api,
        _store = store,
        _installId = installId,
        _notify = notify;

  Future<void> check() async {
    try {
      final tickets = await _api.listTickets(await _installId());
      final fresh = unseenTickets(tickets, _store.watermarks(tickets.map((t) => t.id)));
      for (final t in fresh) {
        final body = t.lastBody.length > bodyLimit ? t.lastBody.substring(0, bodyLimit) : t.lastBody;
        await _notify(ticketId: t.id, body: body);
        await _store.markNotified(t.id, t.lastAt);
      }
    } catch (_) {
      // Offline, RPC missing, or a parse error: silent, next check retries.
    }
  }
}
