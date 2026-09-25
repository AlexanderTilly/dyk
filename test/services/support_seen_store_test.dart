import 'package:flutter_test/flutter_test.dart';
import 'package:palma_app/models/support_ticket.dart';
import 'package:palma_app/services/support_seen_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

SupportTicketSummary ticket(String id, {required bool fromCustomer, required DateTime lastAt}) =>
    SupportTicketSummary(
      id: id, status: 'answered', createdAt: DateTime.utc(2026, 9, 1),
      lastBody: 'x', lastFromCustomer: fromCustomer, lastAt: lastAt, staffCount: 1,
    );

void main() {
  final t0 = DateTime.utc(2026, 9, 25, 9);
  final t1 = DateTime.utc(2026, 9, 25, 10);

  group('unseenTickets (pure)', () {
    test('a staff reply with no watermark is unseen', () {
      expect(unseenTickets([ticket('a', fromCustomer: false, lastAt: t0)], {}).map((t) => t.id), ['a']);
    });
    test('a staff reply older than or equal to the watermark is seen', () {
      expect(unseenTickets([ticket('a', fromCustomer: false, lastAt: t0)], {'a': t0}), isEmpty);
      expect(unseenTickets([ticket('a', fromCustomer: false, lastAt: t0)], {'a': t1}), isEmpty);
    });
    test('a staff reply newer than the watermark is unseen', () {
      expect(unseenTickets([ticket('a', fromCustomer: false, lastAt: t1)], {'a': t0}).length, 1);
    });
    test('the customer\'s own last message is never unseen', () {
      expect(unseenTickets([ticket('a', fromCustomer: true, lastAt: t1)], {}), isEmpty);
    });
  });

  group('SupportSeenStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('watermark is the later of seen and notified', () async {
      final store = SupportSeenStore(await SharedPreferences.getInstance());
      await store.markNotified('a', t0);
      await store.markSeen('a', t1);
      expect(store.watermarks(['a', 'b']), {'a': t1});
    });
    test('isUnseen uses the seen mark only', () async {
      final store = SupportSeenStore(await SharedPreferences.getInstance());
      final t = ticket('a', fromCustomer: false, lastAt: t1);
      expect(store.isUnseen(t), isTrue);
      await store.markNotified('a', t1);
      expect(store.isUnseen(t), isTrue, reason: 'a notification is not the user reading it');
      await store.markSeen('a', t1);
      expect(store.isUnseen(t), isFalse);
    });
    test('values are stored as UTC ISO-8601 strings (shared with the Android isolate)', () async {
      final prefs = await SharedPreferences.getInstance();
      await SupportSeenStore(prefs).markSeen('a', DateTime(2026, 9, 25, 12).toUtc());
      expect(prefs.getString('support_seen_a'), endsWith('Z'));
      expect(DateTime.parse(prefs.getString('support_seen_a')!).isUtc, isTrue);
    });
  });
}
