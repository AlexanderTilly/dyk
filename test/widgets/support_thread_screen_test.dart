import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palma_app/models/support_ticket.dart';
import 'package:palma_app/screens/support_thread_screen.dart';
import 'package:palma_app/services/support_api.dart';
import 'package:palma_app/services/support_seen_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeApi implements SupportApi {
  SupportThread? threadToReturn;
  Object? threadError;
  final replies = <String>[];
  Object? replyError;
  @override
  Future<SupportThread> thread(String ticketId, String installId) async {
    if (threadError != null) throw threadError!;
    return threadToReturn!;
  }
  @override
  Future<String> reply(String ticketId, String installId, String body) async {
    if (replyError != null) throw replyError!;
    replies.add(body);
    return 'm-new';
  }
  @override
  Future<List<SupportTicketSummary>> listTickets(String installId) async => [];
  @override
  Future<void> createTicket({required String email, required String message, String? userId, required String installId}) async {}
}

SupportThread sample() => SupportThread(
      id: 't1', status: 'answered', createdAt: DateTime.utc(2026, 9, 23, 22),
      messages: [
        SupportMessage(id: 'm1', fromCustomer: true, body: 'the pin is wrong', createdAt: DateTime.utc(2026, 9, 23, 22)),
        SupportMessage(id: 'm2', fromCustomer: false, body: 'We moved it.', createdAt: DateTime.utc(2026, 9, 25, 9)),
        SupportMessage(id: 'm3', fromCustomer: true, body: 'Great, appreciate it!', createdAt: DateTime.utc(2026, 9, 25, 10)),
      ],
    );

Future<(FakeApi, SupportSeenStore)> pump(WidgetTester tester, {SupportThread? thread, Object? threadError}) async {
  SharedPreferences.setMockInitialValues({});
  final api = FakeApi();
  api.threadToReturn = thread ?? sample();
  api.threadError = threadError;
  final store = SupportSeenStore(await SharedPreferences.getInstance());
  await tester.pumpWidget(MaterialApp(
    home: SupportThreadScreen(ticketId: 't1', api: api, installId: () async => 'install-1234567890', seenStore: store),
  ));
  await tester.pumpAndSettle();
  return (api, store);
}

void main() {
  testWidgets('renders bubbles with You / Passim Support labels', (tester) async {
    await pump(tester);
    expect(find.text('the pin is wrong'), findsOneWidget);
    expect(find.text('We moved it.'), findsOneWidget);
    expect(find.text('Great, appreciate it!'), findsOneWidget);
    expect(find.text('You'), findsNWidgets(2));
    expect(find.text('Passim Support'), findsWidgets); // app bar + bubble label
    expect(find.textContaining('staff'), findsNothing);
    expect(find.textContaining('Michelle'), findsNothing);
  });

  testWidgets('marks the newest staff reply as seen on open', (tester) async {
    final (_, store) = await pump(tester);
    expect(store.watermarks(['t1'])['t1'], DateTime.utc(2026, 9, 25, 9));
  });

  testWidgets('send is disabled on empty input and sends the trimmed body', (tester) async {
    final (api, _) = await pump(tester);
    final send = find.byKey(const Key('support_send'));
    expect(tester.widget<IconButton>(send).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('support_reply_field')), '  Thanks!  ');
    await tester.pump();
    expect(tester.widget<IconButton>(send).onPressed, isNotNull);
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(api.replies, ['Thanks!']);
    expect(find.text('Thanks!'), findsOneWidget); // appended locally
    expect(tester.widget<TextField>(find.byKey(const Key('support_reply_field'))).controller!.text, '');
  });

  testWidgets('a failed reply keeps the text and shows an error', (tester) async {
    final (api, _) = await pump(tester);
    api.replyError = Exception('offline');
    await tester.enterText(find.byKey(const Key('support_reply_field')), 'Hello');
    await tester.pump();
    await tester.tap(find.byKey(const Key('support_send')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('support_reply_error')), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('support_reply_field'))).controller!.text, 'Hello');
  });

  testWidgets('a deleted conversation pops the screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = SupportSeenStore(await SharedPreferences.getInstance());
    final notFoundApi = FakeApi();
    notFoundApi.threadError = const SupportNotFound();
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => TextButton(
      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SupportThreadScreen(
        ticketId: 't1',
        api: notFoundApi,
        installId: () async => 'install-1234567890',
        seenStore: store,
      ))),
      child: const Text('open'),
    ))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(SupportThreadScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
