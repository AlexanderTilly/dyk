import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:palma_app/models/support_ticket.dart';
import 'package:palma_app/screens/support_screen.dart';
import 'package:palma_app/services/auth_service.dart';
import 'package:palma_app/services/support_api.dart';
import 'package:palma_app/services/support_seen_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// mocktail is already a dev dependency; AuthService.currentUser reads
/// Supabase.instance.client, which is never initialised in a widget test,
/// so a real AuthService cannot be constructed here.
class MockAuthService extends Mock implements AuthService {}

class FakeApi implements SupportApi {
  List<SupportTicketSummary> tickets = [];
  Object? listError;
  final created = <Map<String, String?>>[];
  @override
  Future<List<SupportTicketSummary>> listTickets(String installId) async {
    if (listError != null) throw listError!;
    return tickets;
  }
  @override
  Future<void> createTicket({required String email, required String message, String? userId, required String installId}) async {
    created.add({'email': email, 'message': message, 'install_id': installId});
    tickets = [
      SupportTicketSummary(id: 'new1', status: 'new', createdAt: DateTime.now().toUtc(), lastBody: message,
          lastFromCustomer: true, lastAt: DateTime.now().toUtc(), staffCount: 0),
      ...tickets,
    ];
  }
  @override
  Future<SupportThread> thread(String ticketId, String installId) => throw UnimplementedError();
  @override
  Future<String> reply(String ticketId, String installId, String body) => throw UnimplementedError();
}

SupportTicketSummary staffReply(String id) => SupportTicketSummary(
      id: id, status: 'answered', createdAt: DateTime.utc(2026, 9, 23), lastBody: 'We moved the pin.',
      lastFromCustomer: false, lastAt: DateTime.utc(2026, 9, 25, 9), staffCount: 1,
    );

Future<FakeApi> pump(WidgetTester tester, {List<SupportTicketSummary>? tickets, Object? listError}) async {
  SharedPreferences.setMockInitialValues({});
  final api = FakeApi();
  api.tickets = tickets ?? [];
  api.listError = listError;
  final auth = MockAuthService();
  when(() => auth.currentUser).thenReturn(null);
  await tester.pumpWidget(MaterialApp(
    home: SupportScreen(
      authService: auth,
      api: api,
      installId: () async => 'install-1234567890',
      seenStore: () async => SupportSeenStore(await SharedPreferences.getInstance()),
    ),
  ));
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('no tickets: only the form, no conversations header', (tester) async {
    await pump(tester);
    expect(find.text('Your conversations'), findsNothing);
    expect(find.byKey(const Key('support_message_field')), findsOneWidget);
  });

  testWidgets('tickets render with status chip, unread dot and Passim Support prefix', (tester) async {
    await pump(tester, tickets: [staffReply('a')]);
    expect(find.text('Your conversations'), findsOneWidget);
    expect(find.text('Answered'), findsOneWidget);
    expect(find.textContaining('Passim Support: We moved the pin.'), findsOneWidget);
    expect(find.byKey(const Key('unread_a')), findsOneWidget);
  });

  testWidgets('list failure shows an error with retry and keeps the form', (tester) async {
    await pump(tester, listError: Exception('offline'));
    expect(find.text("Couldn't load your conversations."), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byKey(const Key('support_message_field')), findsOneWidget);
  });

  testWidgets('sending creates a ticket with install_id and shows it on top', (tester) async {
    final api = await pump(tester);
    await tester.enterText(find.byKey(const Key('support_email_field')), 'me@example.com');
    await tester.enterText(find.byKey(const Key('support_message_field')), 'Pin is wrong');
    await tester.tap(find.byKey(const Key('support_send_message')));
    await tester.pumpAndSettle();
    expect(api.created.single['install_id'], 'install-1234567890');
    expect(find.text('Your conversations'), findsOneWidget);
    expect(find.textContaining('You: Pin is wrong'), findsOneWidget);
    expect(find.text("We've got it — you'll see the reply here."), findsOneWidget);
  });
}
