import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/support_ticket.dart';

/// Thrown when the RPC says 'not found' — wrong install_id, or the ticket
/// was deleted in admin.
class SupportNotFound implements Exception {
  const SupportNotFound();
}

/// Every network call the support feature makes. Screens and the reply
/// checker depend on this, never on Supabase directly, so tests inject a fake.
abstract class SupportApi {
  Future<List<SupportTicketSummary>> listTickets(String installId);
  Future<SupportThread> thread(String ticketId, String installId);
  Future<String> reply(String ticketId, String installId, String body);
  Future<void> createTicket({
    required String email,
    required String message,
    String? userId,
    required String installId,
  });
}

class SupabaseSupportApi implements SupportApi {
  final SupabaseClient _client;
  SupabaseSupportApi({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Never _rethrow(Object e) {
    if (e is PostgrestException && e.message.contains('not found')) {
      throw const SupportNotFound();
    }
    throw e;
  }

  @override
  Future<List<SupportTicketSummary>> listTickets(String installId) async {
    try {
      final res = await _client.rpc('support_my_tickets', params: {'p_install_id': installId});
      return ((res as List?) ?? const [])
          .map((r) => SupportTicketSummary.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<SupportThread> thread(String ticketId, String installId) async {
    try {
      final res = await _client.rpc('support_thread',
          params: {'p_ticket_id': ticketId, 'p_install_id': installId});
      return SupportThread.fromJson(Map<String, dynamic>.from(res as Map));
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<String> reply(String ticketId, String installId, String body) async {
    try {
      final res = await _client.rpc('support_reply',
          params: {'p_ticket_id': ticketId, 'p_install_id': installId, 'p_body': body});
      return res as String;
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> createTicket({
    required String email,
    required String message,
    String? userId,
    required String installId,
  }) async {
    await _client.from('support_tickets').insert({
      'email': email,
      'message': message,
      'user_id': userId,
      'install_id': installId,
    });
  }
}
