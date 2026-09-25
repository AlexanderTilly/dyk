import 'package:flutter_test/flutter_test.dart';
import 'package:palma_app/models/support_ticket.dart';

void main() {
  group('SupportTicketSummary.fromJson', () {
    test('parses the RPC row and timestamps as UTC', () {
      final t = SupportTicketSummary.fromJson({
        'id': 't1',
        'status': 'answered',
        'created_at': '2026-09-23T22:00:00+00:00',
        'last_body': 'We moved the pin.',
        'last_from_customer': false,
        'last_at': '2026-09-25T09:15:30.123456+00:00',
        'staff_count': 1,
      });
      expect(t.id, 't1');
      expect(t.status, 'answered');
      expect(t.lastBody, 'We moved the pin.');
      expect(t.lastFromCustomer, isFalse);
      expect(t.staffCount, 1);
      expect(t.lastAt.isUtc, isTrue);
      expect(t.lastAt, DateTime.utc(2026, 9, 25, 9, 15, 30, 123, 456));
    });
    test('tolerates nulls from a legacy ticket', () {
      final t = SupportTicketSummary.fromJson({
        'id': 't2', 'status': 'new', 'created_at': '2026-09-01T00:00:00+00:00',
        'last_body': null, 'last_from_customer': null, 'last_at': null, 'staff_count': null,
      });
      expect(t.lastBody, '');
      expect(t.lastFromCustomer, isTrue);
      expect(t.lastAt, t.createdAt);
      expect(t.staffCount, 0);
    });
  });

  group('SupportThread.fromJson', () {
    test('parses messages in the order given', () {
      final th = SupportThread.fromJson({
        'id': 't1', 'status': 'answered', 'created_at': '2026-09-23T22:00:00+00:00',
        'messages': [
          {'id': 'm1', 'from_customer': true, 'body': 'wrong pin', 'created_at': '2026-09-23T22:00:00+00:00'},
          {'id': 'm2', 'from_customer': false, 'body': 'Fixed.', 'created_at': '2026-09-25T09:00:00+00:00'},
        ],
      });
      expect(th.messages.map((m) => m.id), ['m1', 'm2']);
      expect(th.messages[0].fromCustomer, isTrue);
      expect(th.messages[1].fromCustomer, isFalse);
      expect(th.messages[1].body, 'Fixed.');
    });
    test('empty messages array', () {
      final th = SupportThread.fromJson({'id': 't', 'status': 'new', 'created_at': '2026-09-01T00:00:00Z', 'messages': []});
      expect(th.messages, isEmpty);
    });
  });
}
