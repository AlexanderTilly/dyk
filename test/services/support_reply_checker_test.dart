import 'package:flutter_test/flutter_test.dart';
import 'package:palma_app/models/support_ticket.dart';
import 'package:palma_app/services/support_api.dart';
import 'package:palma_app/services/support_reply_checker.dart';
import 'package:palma_app/services/support_seen_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeApi implements SupportApi {
  List<SupportTicketSummary> tickets = [];
  Object? failWith;
  @override
  Future<List<SupportTicketSummary>> listTickets(String installId) async {
    if (failWith != null) throw failWith!;
    return tickets;
  }
  @override
  Future<SupportThread> thread(String ticketId, String installId) => throw UnimplementedError();
  @override
  Future<String> reply(String ticketId, String installId, String body) => throw UnimplementedError();
  @override
  Future<void> createTicket({required String email, required String message, String? userId, required String installId}) =>
      throw UnimplementedError();
}

SupportTicketSummary staffReply(String id, DateTime at, [String body = 'Reply']) => SupportTicketSummary(
      id: id, status: 'answered', createdAt: DateTime.utc(2026, 9, 1),
      lastBody: body, lastFromCustomer: false, lastAt: at, staffCount: 1,
    );

void main() {
  final t0 = DateTime.utc(2026, 9, 25, 9);
  final t1 = DateTime.utc(2026, 9, 25, 10);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(SupportReplyChecker, FakeApi, List<Map<String, String>>)> build() async {
    final api = FakeApi();
    final store = SupportSeenStore(await SharedPreferences.getInstance());
    final shown = <Map<String, String>>[];
    final checker = SupportReplyChecker(
      api: api,
      store: store,
      installId: () async => 'install-1234567890',
      notify: ({required ticketId, required body}) async => shown.add({'id': ticketId, 'body': body}),
    );
    return (checker, api, shown);
  }

  test('notifies once per new staff reply and truncates the body to 80 chars', () async {
    final (checker, api, shown) = await build();
    api.tickets = [staffReply('a', t0, 'x' * 100)];
    await checker.check();
    await checker.check();
    expect(shown.length, 1);
    expect(shown.single['id'], 'a');
    expect(shown.single['body']!.length, 80);
  });

  test('a newer reply on the same ticket notifies again', () async {
    final (checker, api, shown) = await build();
    api.tickets = [staffReply('a', t0)];
    await checker.check();
    api.tickets = [staffReply('a', t1)];
    await checker.check();
    expect(shown.length, 2);
  });

  test('a reply the user already opened is not notified', () async {
    final (checker, api, shown) = await build();
    final store = SupportSeenStore(await SharedPreferences.getInstance());
    await store.markSeen('a', t0);
    api.tickets = [staffReply('a', t0)];
    await checker.check();
    expect(shown, isEmpty);
  });

  test('the customer\'s own message never notifies', () async {
    final (checker, api, shown) = await build();
    api.tickets = [SupportTicketSummary(id: 'a', status: 'new', createdAt: t0, lastBody: 'me', lastFromCustomer: true, lastAt: t1, staffCount: 0)];
    await checker.check();
    expect(shown, isEmpty);
  });

  test('network failure is swallowed', () async {
    final (checker, api, shown) = await build();
    api.failWith = Exception('offline');
    await expectLater(checker.check(), completes);
    expect(shown, isEmpty);
  });
}
