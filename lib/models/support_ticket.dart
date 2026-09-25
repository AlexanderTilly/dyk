/// Rows returned by the support RPCs (045: support_thread; 047:
/// support_my_tickets). Timestamps are parsed to UTC so the app's
/// "seen"/"notified" watermarks compare correctly with what the Android
/// isolate writes.
library;

DateTime _utc(dynamic v, {DateTime? fallback}) {
  if (v is String && v.isNotEmpty) return DateTime.parse(v).toUtc();
  return (fallback ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true));
}

class SupportTicketSummary {
  final String id;
  final String status; // 'new' | 'answered' | 'closed'
  final DateTime createdAt;
  final String lastBody;
  final bool lastFromCustomer;
  final DateTime lastAt;
  final int staffCount;

  const SupportTicketSummary({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.lastBody,
    required this.lastFromCustomer,
    required this.lastAt,
    required this.staffCount,
  });

  factory SupportTicketSummary.fromJson(Map<String, dynamic> j) {
    final createdAt = _utc(j['created_at']);
    return SupportTicketSummary(
      id: j['id'] as String,
      status: (j['status'] as String?) ?? 'new',
      createdAt: createdAt,
      lastBody: (j['last_body'] as String?) ?? '',
      lastFromCustomer: (j['last_from_customer'] as bool?) ?? true,
      lastAt: _utc(j['last_at'], fallback: createdAt),
      staffCount: (j['staff_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class SupportMessage {
  final String id;
  final bool fromCustomer;
  final String body;
  final DateTime createdAt;

  const SupportMessage({
    required this.id,
    required this.fromCustomer,
    required this.body,
    required this.createdAt,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> j) => SupportMessage(
        id: j['id'] as String,
        fromCustomer: (j['from_customer'] as bool?) ?? true,
        body: (j['body'] as String?) ?? '',
        createdAt: _utc(j['created_at']),
      );
}

class SupportThread {
  final String id;
  final String status;
  final DateTime createdAt;
  final List<SupportMessage> messages;

  const SupportThread({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.messages,
  });

  factory SupportThread.fromJson(Map<String, dynamic> j) => SupportThread(
        id: j['id'] as String,
        status: (j['status'] as String?) ?? 'new',
        createdAt: _utc(j['created_at']),
        messages: ((j['messages'] as List?) ?? const [])
            .map((m) => SupportMessage.fromJson(Map<String, dynamic>.from(m as Map)))
            .toList(),
      );
}
