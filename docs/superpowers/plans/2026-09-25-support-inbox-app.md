# Support Inbox in the App (Michelle v2 — sub-project C) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Passim app shows a customer's support conversations, lets them reply, and notifies them (locally) when Passim Support has answered — signed in or guest, keyed by the device's `install_id`.

**Architecture:** One new RPC (`support_my_tickets`) lists a device's tickets. In the app, a small `SupportApi` interface wraps the four network calls so screens and the reply checker are testable with a fake. A pure `unseenTickets()` function plus a SharedPreferences-backed `SupportSeenStore` decide what is new; `SupportReplyChecker` runs it on launch/resume and shows a local notification; the Android foreground isolate mirrors the same check over plain HTTP every ~5 minutes. The support screen becomes list + form; a new thread screen shows bubbles and a reply box.

**Tech Stack:** Flutter 3.44 / Dart 3, `supabase_flutter` 2, `shared_preferences`, `flutter_local_notifications`, `flutter_foreground_task` (existing), `http` (existing), `flutter_test`. Postgres/Supabase for the migration.

**Spec:** `C:/Users/tilly/palma_app/docs/superpowers/specs/2026-09-25-support-inbox-app-design.md` — read it first.

## Global Constraints

- **One identity path:** every ticket the app creates carries `install_id` = the device's existing `anon_install_id` (SharedPreferences key `anon_install_id`, created by `DeviceProfileService.recordInstall()`); every read goes through the `install_id` RPCs. No RLS path, no `user_id` reads.
- **Customer-facing labels:** the customer's own messages are "You"; every other message is "Passim Support". The words "staff" and "Michelle" never appear in the app.
- **Reply body 1–4000 chars after trim** (mirrors DB check and `support_reply`).
- **Notification rule:** one local notification per ticket per new staff reply, payload `support:<ticket_id>`, title from i18n key `support_reply_notif_title`, body = first 80 characters of the reply. Never re-notify a reply the user has already seen (thread opened) or already been notified about. Watermarks are ISO-8601 UTC strings written by `DateTime.toUtc().toIso8601String()` and compared as `DateTime`s — both in the app and in the Android isolate.
- **Check points:** app launch (after telemetry) and every `AppLifecycleState.resumed`; Android isolate every 25th tick (~5 min); notification tap routes to the thread; unknown id → support list.
- **Languages:** every new user-visible string exists in `en`, `es`, `ca`, `de` in `lib/i18n/i18n.dart` (and in the isolate's `_notifStrings` for the notification title).
- **Tests never hit the network:** screens and the checker take `SupportApi` (fake in tests); the store takes `SharedPreferences` (`setMockInitialValues` in tests).
- **Repo:** `C:/Users/tilly/palma_app`, branch `main`. Commit only the files each task names — `design/city_headers/` and `supabase/.temp/` are pre-existing untracked entries that must never be added. Never push; the owner pushes via GitHub Desktop.
- **Migration 047 is applied by the owner** in the Supabase SQL Editor (project `jqykkyhoxpykhixwgwyw`); the app code must not assume it exists until the owner confirms.
- **Analyze gate:** `flutter analyze` must report no issues (the Codemagic iOS workflow gates on it).

---

## File Structure

```
supabase/migrations/047_support_my_tickets.sql       the list RPC

lib/models/support_ticket.dart                       SupportTicketSummary, SupportMessage, SupportThread (+fromJson)
lib/services/support_api.dart                        SupportApi interface + SupabaseSupportApi
lib/services/device_profile_service.dart             MODIFIED: installId()
lib/services/support_seen_store.dart                 unseenTickets() (pure) + SupportSeenStore (prefs)
lib/services/support_reply_checker.dart              SupportReplyChecker
lib/services/notification_service.dart               MODIFIED: showSupportReplyNotification()
lib/services/geofence_task_handler.dart              MODIFIED: 5-minute support check + notif strings
lib/screens/support_screen.dart                      REBUILT: conversations list + new-message form
lib/screens/support_thread_screen.dart               NEW: bubbles + reply box
lib/main.dart                                        MODIFIED: lifecycle observer, launch check, 'support:' route
lib/i18n/i18n.dart                                   MODIFIED: new keys ×4 languages
pubspec.yaml                                         MODIFIED (Task 9): version bump

test/models/support_ticket_test.dart
test/services/support_seen_store_test.dart
test/services/support_reply_checker_test.dart
test/widgets/support_thread_screen_test.dart
test/widgets/support_screen_test.dart
```

---

### Task 1: Migration `047_support_my_tickets.sql`

**Files:**
- Create: `supabase/migrations/047_support_my_tickets.sql`

**Interfaces:**
- Produces: RPC `support_my_tickets(p_install_id text) → jsonb` — array, newest activity first, elements `{ id, status, created_at, last_body, last_from_customer, last_at, staff_count }`. `last_*` fall back to the ticket's own `message`/`created_at` when a ticket has no messages. Raises `not found` for null/short `p_install_id`. Returns `[]` when the device has no tickets.

- [ ] **Step 1: Write the migration**

```sql
-- 047_support_my_tickets.sql — list a device's support conversations.
-- Idempotent. Run in Supabase → SQL Editor as the default (postgres) user.
--
-- Companion to 045's support_thread / support_reply: same trust model
-- (knowing an install_id grants access to that device's tickets), same
-- 'not found' for a null or short id. last_* describe the newest message;
-- a ticket with no messages (a legacy ticket whose text exceeded the
-- 4000-char backfill limit) falls back to its own message and created_at.

create or replace function public.support_my_tickets(p_install_id text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v jsonb;
begin
  if p_install_id is null or length(p_install_id) < 8 then
    raise exception 'not found';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', t.id,
           'status', t.status,
           'created_at', t.created_at,
           'last_body', coalesce(m.body, t.message),
           'last_from_customer', coalesce(m.author = 'customer', true),
           'last_at', coalesce(m.created_at, t.created_at),
           'staff_count', (select count(*) from public.support_messages s
                            where s.ticket_id = t.id and s.author <> 'customer')
         ) order by coalesce(m.created_at, t.created_at) desc), '[]'::jsonb)
    into v
    from public.support_tickets t
    left join lateral (
      select body, author, created_at
        from public.support_messages
       where ticket_id = t.id
       order by created_at desc
       limit 1
    ) m on true
   where t.install_id = p_install_id;
  return v;
end $$;
revoke all on function public.support_my_tickets(text) from public;
grant execute on function public.support_my_tickets(text) to anon, authenticated;
```

- [ ] **Step 2: Read it once top to bottom**

Check: `create or replace`; `security definer` + `set search_path = public`; the `revoke`/`grant` pair names the exact signature `(text)`; the `order by` inside `jsonb_agg` uses the same expression as `last_at`.

- [ ] **Step 3: Commit (this file only)**

```bash
cd C:/Users/tilly/palma_app
git add supabase/migrations/047_support_my_tickets.sql
git commit -m "feat(db): support_my_tickets — list a device's support conversations (047)"
git status --short   # only design/city_headers/ and supabase/.temp/ may remain
```

- [ ] **Step 4: Owner step — apply and verify**

Owner pastes the file into Supabase → SQL Editor → Run. Then, in the editor:
```sql
select proname from pg_proc where proname = 'support_my_tickets';
select public.support_my_tickets('no-such-install-id-xxxxxxxx');   -- expected: []
```

---

### Task 2: Models and `SupportApi`

**Files:**
- Create: `lib/models/support_ticket.dart`
- Create: `lib/services/support_api.dart`
- Test: `test/models/support_ticket_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class SupportTicketSummary { final String id, status, lastBody; final DateTime createdAt, lastAt; final bool lastFromCustomer; final int staffCount; factory fromJson(Map<String, dynamic>) }
  class SupportMessage { final String id, body; final bool fromCustomer; final DateTime createdAt; factory fromJson }
  class SupportThread { final String id, status; final DateTime createdAt; final List<SupportMessage> messages; factory fromJson }
  abstract class SupportApi {
    Future<List<SupportTicketSummary>> listTickets(String installId);
    Future<SupportThread> thread(String ticketId, String installId);
    Future<String> reply(String ticketId, String installId, String body);
    Future<void> createTicket({required String email, required String message, String? userId, required String installId});
  }
  class SupabaseSupportApi implements SupportApi { SupabaseSupportApi({SupabaseClient? client}) }
  class SupportNotFound implements Exception {}
  ```

- [ ] **Step 1: Write the failing test**

```dart
// test/models/support_ticket_test.dart
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
```

- [ ] **Step 2: Run to verify it fails**

```bash
cd C:/Users/tilly/palma_app
flutter test test/models/support_ticket_test.dart
```
Expected: FAIL — `package:palma_app/models/support_ticket.dart` not found.

- [ ] **Step 3: Write the models**

```dart
// lib/models/support_ticket.dart
/// Rows returned by the support RPCs (045: support_thread; 047:
/// support_my_tickets). Timestamps are parsed to UTC so the app's
/// "seen"/"notified" watermarks compare correctly with what the Android
/// isolate writes.

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
```

- [ ] **Step 4: Run to verify it passes**

```bash
flutter test test/models/support_ticket_test.dart
```
Expected: 4 pass.

- [ ] **Step 5: Write `SupportApi`** (no unit test — it is the Supabase adapter; the fake in later tests implements the same interface, and Task 9 exercises it live)

```dart
// lib/services/support_api.dart
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
```

- [ ] **Step 6: Analyze and commit**

```bash
flutter analyze lib/models/support_ticket.dart lib/services/support_api.dart
git add lib/models/support_ticket.dart lib/services/support_api.dart test/models/support_ticket_test.dart
git commit -m "feat(support): ticket/thread models and SupportApi over the install_id RPCs"
```

---

### Task 3: `installId()` and the seen/notified store

**Files:**
- Modify: `lib/services/device_profile_service.dart` (add one method)
- Create: `lib/services/support_seen_store.dart`
- Test: `test/services/support_seen_store_test.dart`

**Interfaces:**
- Consumes: `SupportTicketSummary` (Task 2).
- Produces:
  ```dart
  // DeviceProfileService
  Future<String> installId();   // the same anon_install_id recordInstall() stores; created if missing
  // support_seen_store.dart
  List<SupportTicketSummary> unseenTickets(List<SupportTicketSummary> tickets, Map<String, DateTime> watermarks);
  class SupportSeenStore {
    SupportSeenStore(SharedPreferences prefs);
    static Future<SupportSeenStore> load();
    Map<String, DateTime> watermarks(Iterable<String> ticketIds);   // max(seen, notified) per id
    Future<void> markSeen(String ticketId, DateTime at);
    Future<void> markNotified(String ticketId, DateTime at);
    bool isUnseen(SupportTicketSummary t);                           // staff reply newer than seen
  }
  ```
  Keys: `support_seen_<id>`, `support_notified_<id>`; values `DateTime.toUtc().toIso8601String()`.

- [ ] **Step 1: Write the failing test**

```dart
// test/services/support_seen_store_test.dart
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
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/services/support_seen_store_test.dart
```
Expected: FAIL — module not found.

- [ ] **Step 3: Implement the store**

```dart
// lib/services/support_seen_store.dart
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
```

- [ ] **Step 4: Add `installId()` to `DeviceProfileService`** — insert right before `recordInstall()`:

```dart
  /// The device's anonymous install id — the same value recordInstall()
  /// writes, created here if this runs first. Support tickets carry it so a
  /// guest can read replies on the same device.
  Future<String> installId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString('anon_install_id');
    if (existing != null && existing.isNotEmpty) return existing;
    final fresh = const Uuid().v4();
    await prefs.setString('anon_install_id', fresh);
    return fresh;
  }
```

- [ ] **Step 5: Run tests, analyze, commit**

```bash
flutter test test/services/support_seen_store_test.dart
flutter analyze lib/services/support_seen_store.dart lib/services/device_profile_service.dart
git add lib/services/support_seen_store.dart lib/services/device_profile_service.dart test/services/support_seen_store_test.dart
git commit -m "feat(support): unseen-reply logic, seen/notified store, DeviceProfileService.installId()"
```
Expected: 7 pass, analyzer clean.

---

### Task 4: Notification + `SupportReplyChecker`

**Files:**
- Modify: `lib/services/notification_service.dart` (add one method)
- Create: `lib/services/support_reply_checker.dart`
- Test: `test/services/support_reply_checker_test.dart`

**Interfaces:**
- Consumes: `SupportApi`, `SupportTicketSummary` (Task 2); `SupportSeenStore`, `unseenTickets` (Task 3).
- Produces:
  ```dart
  // NotificationService
  Future<void> showSupportReplyNotification({required String ticketId, required String title, required String body});
  // SupportReplyChecker
  typedef SupportNotify = Future<void> Function({required String ticketId, required String body});
  class SupportReplyChecker {
    SupportReplyChecker({required SupportApi api, required SupportSeenStore store, required Future<String> Function() installId, required SupportNotify notify});
    Future<void> check();   // never throws
  }
  ```

- [ ] **Step 1: Write the failing test**

```dart
// test/services/support_reply_checker_test.dart
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
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/services/support_reply_checker_test.dart
```
Expected: FAIL — module not found.

- [ ] **Step 3: Implement the checker**

```dart
// lib/services/support_reply_checker.dart
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
```

- [ ] **Step 4: Add the notification method** — append inside `NotificationService`, after `showDealNotification`:

```dart
  /// A staff reply on a support ticket. Tapping routes to the thread
  /// (payload 'support:<ticketId>', handled in main.dart).
  Future<void> showSupportReplyNotification({
    required String ticketId,
    required String title,
    required String body,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'support_channel',
      'Support',
      channelDescription: 'Replies from Passim Support',
      importance: Importance.high,
      priority: Priority.high,
      color: dykNotificationColor,
      colorized: true,
      largeIcon: dykLargeIcon,
    );
    const iosDetails = DarwinNotificationDetails();
    await _plugin.show(
      ticketId.hashCode,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: 'support:$ticketId',
    );
  }
```

- [ ] **Step 5: Run tests, analyze, commit**

```bash
flutter test test/services/support_reply_checker_test.dart
flutter analyze lib/services/support_reply_checker.dart lib/services/notification_service.dart
git add lib/services/support_reply_checker.dart lib/services/notification_service.dart test/services/support_reply_checker_test.dart
git commit -m "feat(support): SupportReplyChecker and the support-reply notification"
```
Expected: 5 pass, analyzer clean.

---

### Task 5: i18n keys (four languages)

**Files:**
- Modify: `lib/i18n/i18n.dart` — add the keys below inside each language map (`'en': {`, `'es': {`, `'ca': {`, `'de': {`), next to the existing support keys (`'help_support'` …). Replace the existing `'message_sent_sub'` value in each language.

**Interfaces:**
- Produces: `tr('your_conversations')`, `tr('passim_support')`, `tr('you')`, `tr('status_open')`, `tr('status_answered')`, `tr('status_closed')`, `tr('reply_placeholder')`, `tr('send_reply')`, `tr('no_conversations_yet')`, `tr('couldnt_load_conversations')`, `tr('retry')`, `tr('conversation_gone')`, `tr('message_sent_sub')`, `tr('support_reply_notif_title')`, `tr('new_message')`.

- [ ] **Step 1: Add the keys**

```dart
    // en
    'your_conversations': 'Your conversations',
    'new_message': 'New message',
    'passim_support': 'Passim Support',
    'you': 'You',
    'status_open': 'Open',
    'status_answered': 'Answered',
    'status_closed': 'Closed',
    'reply_placeholder': 'Write a reply…',
    'send_reply': 'Send',
    'no_conversations_yet': 'No conversations yet.',
    'couldnt_load_conversations': "Couldn't load your conversations.",
    'retry': 'Retry',
    'conversation_gone': 'This conversation is no longer available.',
    'message_sent_sub': "We've got it — you'll see the reply here.",
    'support_reply_notif_title': 'Passim Support replied',
```
```dart
    // es
    'your_conversations': 'Tus conversaciones',
    'new_message': 'Nuevo mensaje',
    'passim_support': 'Soporte de Passim',
    'you': 'Tú',
    'status_open': 'Abierto',
    'status_answered': 'Respondido',
    'status_closed': 'Cerrado',
    'reply_placeholder': 'Escribe una respuesta…',
    'send_reply': 'Enviar',
    'no_conversations_yet': 'Aún no hay conversaciones.',
    'couldnt_load_conversations': 'No se pudieron cargar tus conversaciones.',
    'retry': 'Reintentar',
    'conversation_gone': 'Esta conversación ya no está disponible.',
    'message_sent_sub': 'Recibido — verás la respuesta aquí.',
    'support_reply_notif_title': 'Soporte de Passim ha respondido',
```
```dart
    // ca
    'your_conversations': 'Les teves converses',
    'new_message': 'Missatge nou',
    'passim_support': 'Suport de Passim',
    'you': 'Tu',
    'status_open': 'Obert',
    'status_answered': 'Respost',
    'status_closed': 'Tancat',
    'reply_placeholder': 'Escriu una resposta…',
    'send_reply': 'Envia',
    'no_conversations_yet': 'Encara no hi ha converses.',
    'couldnt_load_conversations': 'No s\'han pogut carregar les converses.',
    'retry': 'Torna-ho a provar',
    'conversation_gone': 'Aquesta conversa ja no està disponible.',
    'message_sent_sub': 'Rebut — veuràs la resposta aquí.',
    'support_reply_notif_title': 'Suport de Passim ha respost',
```
```dart
    // de
    'your_conversations': 'Deine Unterhaltungen',
    'new_message': 'Neue Nachricht',
    'passim_support': 'Passim Support',
    'you': 'Du',
    'status_open': 'Offen',
    'status_answered': 'Beantwortet',
    'status_closed': 'Geschlossen',
    'reply_placeholder': 'Antwort schreiben…',
    'send_reply': 'Senden',
    'no_conversations_yet': 'Noch keine Unterhaltungen.',
    'couldnt_load_conversations': 'Deine Unterhaltungen konnten nicht geladen werden.',
    'retry': 'Erneut versuchen',
    'conversation_gone': 'Diese Unterhaltung ist nicht mehr verfügbar.',
    'message_sent_sub': 'Angekommen — die Antwort siehst du hier.',
    'support_reply_notif_title': 'Passim Support hat geantwortet',
```

- [ ] **Step 2: Verify every key exists in all four maps**

```bash
cd C:/Users/tilly/palma_app
for k in your_conversations new_message passim_support you status_open status_answered status_closed reply_placeholder send_reply no_conversations_yet couldnt_load_conversations retry conversation_gone message_sent_sub support_reply_notif_title; do n=$(grep -c "'$k':" lib/i18n/i18n.dart); [ "$n" = "4" ] || echo "MISSING: $k has $n/4"; done; echo checked
```
Expected: only `checked`. Then `flutter test test/i18n` (the existing i18n tests must still pass) and `flutter analyze lib/i18n/i18n.dart`.

- [ ] **Step 3: Commit**

```bash
git add lib/i18n/i18n.dart
git commit -m "feat(i18n): support inbox strings in en/es/ca/de"
```

---

### Task 6: Thread screen

**Files:**
- Create: `lib/screens/support_thread_screen.dart`
- Test: `test/widgets/support_thread_screen_test.dart`

**Interfaces:**
- Consumes: `SupportApi`, `SupportThread`, `SupportMessage`, `SupportNotFound` (Task 2); `SupportSeenStore` (Task 3); `tr()` (Task 5); `timeAgo(DateTime)` from `lib/utils/time_ago.dart`.
- Produces: `SupportThreadScreen({required String ticketId, required SupportApi api, required Future<String> Function() installId, required SupportSeenStore seenStore})`. Pops itself (with `tr('conversation_gone')` snack) on `SupportNotFound`.

- [ ] **Step 1: Write the failing widget test**

```dart
// test/widgets/support_thread_screen_test.dart
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
    expect(find.text('You'), findsOneWidget);
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
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/widgets/support_thread_screen_test.dart
```
Expected: FAIL — module not found.

- [ ] **Step 3: Implement the screen**

```dart
// lib/screens/support_thread_screen.dart
import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../models/support_ticket.dart';
import '../services/support_api.dart';
import '../services/support_seen_store.dart';
import '../theme/dyk_theme.dart';
import '../utils/time_ago.dart';

/// One support conversation. The customer's messages sit on the right as
/// "You"; everything else is "Passim Support" — the app never shows who on
/// the team (or which machine) wrote a reply.
class SupportThreadScreen extends StatefulWidget {
  final String ticketId;
  final SupportApi api;
  final Future<String> Function() installId;
  final SupportSeenStore seenStore;

  const SupportThreadScreen({
    super.key,
    required this.ticketId,
    required this.api,
    required this.installId,
    required this.seenStore,
  });

  @override
  State<SupportThreadScreen> createState() => _SupportThreadScreenState();
}

class _SupportThreadScreenState extends State<SupportThreadScreen> {
  static const maxChars = 4000;

  final _reply = TextEditingController();
  final _scroll = ScrollController();
  SupportThread? _thread;
  bool _loading = true;
  bool _sending = false;
  String? _loadError;
  String? _sendError;

  @override
  void initState() {
    super.initState();
    _reply.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _reply.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final t = await widget.api.thread(widget.ticketId, await widget.installId());
      final newestStaff = t.messages.where((m) => !m.fromCustomer).fold<DateTime?>(
          null, (best, m) => best == null || m.createdAt.isAfter(best) ? m.createdAt : best);
      if (newestStaff != null) await widget.seenStore.markSeen(t.id, newestStaff);
      if (!mounted) return;
      setState(() {
        _thread = t;
        _loading = false;
      });
      _jumpToEnd();
    } on SupportNotFound {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('conversation_gone'))));
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = tr('couldnt_load_conversations');
      });
    }
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  String get _trimmed => _reply.text.trim();
  bool get _canSend => !_sending && _trimmed.isNotEmpty && _trimmed.length <= maxChars;

  Future<void> _send() async {
    final body = _trimmed;
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      final id = await widget.api.reply(widget.ticketId, await widget.installId(), body);
      if (!mounted) return;
      setState(() {
        _thread = SupportThread(
          id: _thread!.id,
          status: 'new',
          createdAt: _thread!.createdAt,
          messages: [
            ..._thread!.messages,
            SupportMessage(id: id, fromCustomer: true, body: body, createdAt: DateTime.now().toUtc()),
          ],
        );
        _reply.clear();
      });
      _jumpToEnd();
    } catch (_) {
      if (!mounted) return;
      setState(() => _sendError = tr('support_err_send'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _statusLabel(String s) => s == 'answered'
      ? tr('status_answered')
      : s == 'closed'
          ? tr('status_closed')
          : tr('status_open');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('passim_support'), style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          if (_thread != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(label: Text(_statusLabel(_thread!.status)), visualDensity: VisualDensity.compact),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_loadError!),
                            const SizedBox(height: 8),
                            TextButton(onPressed: _load, child: Text(tr('retry'))),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        itemCount: _thread!.messages.length,
                        itemBuilder: (_, i) => _Bubble(message: _thread!.messages[i]),
                      ),
          ),
          if (_sendError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_sendError!, key: const Key('support_reply_error'),
                  style: const TextStyle(color: Colors.red, fontSize: 13)),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 6, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('support_reply_field'),
                      controller: _reply,
                      minLines: 1,
                      maxLines: 5,
                      enabled: !_sending && _thread != null,
                      decoration: InputDecoration(
                        hintText: tr('reply_placeholder'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('support_send'),
                    tooltip: tr('send_reply'),
                    color: DykColors.yellow,
                    onPressed: _canSend ? _send : null,
                    icon: _sending
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
    );
  }
}

class _Bubble extends StatelessWidget {
  final SupportMessage message;
  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final mine = message.fromCustomer;
    final theme = Theme.of(context);
    final bg = mine ? DykColors.yellow.withValues(alpha: 0.22) : theme.colorScheme.surfaceContainerHighest;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(mine ? 14 : 3),
              bottomRight: Radius.circular(mine ? 3 : 14),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(mine ? tr('you') : tr('passim_support'),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(message.body, style: const TextStyle(fontSize: 15, height: 1.35)),
              const SizedBox(height: 3),
              Text(timeAgo(message.createdAt),
                  style: TextStyle(fontSize: 10, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6))),
            ],
          ),
        ),
      ),
    );
  }
}
```

If `theme.colorScheme.surfaceContainerHighest` does not exist in this Flutter version's theme, use `DykColors`'s existing surface colour (look in `lib/theme/dyk_theme.dart` for a card/surface colour) and say so in the report.

- [ ] **Step 4: Run tests, analyze, commit**

```bash
flutter test test/widgets/support_thread_screen_test.dart
flutter analyze lib/screens/support_thread_screen.dart
git add lib/screens/support_thread_screen.dart test/widgets/support_thread_screen_test.dart
git commit -m "feat(support): thread screen — bubbles, reply box, seen-mark on open"
```
Expected: 5 pass, analyzer clean.

---

### Task 7: Support screen — conversations list + new-message form

**Files:**
- Rewrite: `lib/screens/support_screen.dart`
- Test: `test/widgets/support_screen_test.dart`

**Interfaces:**
- Consumes: `SupportApi`, `SupportTicketSummary`, `SupabaseSupportApi` (Task 2); `SupportSeenStore`, `DeviceProfileService.installId` (Task 3); `SupportThreadScreen` (Task 6); `tr()` (Task 5); `timeAgo`.
- Produces: `SupportScreen({required AuthService authService, SupportApi? api, Future<String> Function()? installId, Future<SupportSeenStore> Function()? seenStore})` — the two existing call sites (`profile_tab.dart:290`, `settings_screen.dart:360`) keep passing only `authService`; the optional parameters default to the real implementations.

- [ ] **Step 1: Write the failing widget test**

```dart
// test/widgets/support_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palma_app/models/support_ticket.dart';
import 'package:palma_app/screens/support_screen.dart';
import 'package:palma_app/services/auth_service.dart';
import 'package:palma_app/services/support_api.dart';
import 'package:palma_app/services/support_seen_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  await tester.pumpWidget(MaterialApp(
    home: SupportScreen(
      authService: AuthService.forTests(),
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
```

`AuthService.forTests()` does not exist yet. Read `lib/services/auth_service.dart`: it wraps a `SupabaseClient`. Add a minimal named constructor **only if** the class cannot be built without Supabase initialisation; the preferred route is to make `SupportScreen` read `authService.currentUser?.email` and `?.id` lazily (it already does) and pass a real `AuthService()` if its constructor does not touch `Supabase.instance` eagerly. Check, then either use `AuthService()` in the test or add `AuthService.forTests()` returning an instance whose `currentUser` is `null` — and document which in the report.

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/widgets/support_screen_test.dart
```
Expected: FAIL — the new constructor parameters and keys do not exist.

- [ ] **Step 3: Rewrite the screen**

```dart
// lib/screens/support_screen.dart
import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../models/support_ticket.dart';
import '../services/auth_service.dart';
import '../services/device_profile_service.dart';
import '../services/support_api.dart';
import '../services/support_seen_store.dart';
import '../theme/dyk_theme.dart';
import '../utils/time_ago.dart';
import '../widgets/passim_background.dart';
import 'support_thread_screen.dart';

/// Help & Support: the device's conversations (tap to open a thread) and the
/// form to start a new one. Works for guests — everything is keyed by the
/// device's install id, and the reply shows up here, not by email.
class SupportScreen extends StatefulWidget {
  final AuthService authService;
  final SupportApi? api;
  final Future<String> Function()? installId;
  final Future<SupportSeenStore> Function()? seenStore;

  const SupportScreen({
    super.key,
    required this.authService,
    this.api,
    this.installId,
    this.seenStore,
  });

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  late final SupportApi _api = widget.api ?? SupabaseSupportApi();
  late final Future<String> Function() _installId =
      widget.installId ?? DeviceProfileService().installId;
  late final Future<SupportSeenStore> Function() _seenStore =
      widget.seenStore ?? SupportSeenStore.load;

  late final TextEditingController _email;
  final _message = TextEditingController();
  List<SupportTicketSummary> _tickets = [];
  SupportSeenStore? _store;
  bool _loadingList = true;
  String? _listError;
  bool _sending = false;
  bool _justSent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.authService.currentUser?.email ?? '');
    _load();
  }

  @override
  void dispose() {
    _email.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loadingList = true;
      _listError = null;
    });
    try {
      _store ??= await _seenStore();
      final list = await _api.listTickets(await _installId());
      if (!mounted) return;
      setState(() {
        _tickets = list;
        _loadingList = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingList = false;
        _listError = tr('couldnt_load_conversations');
      });
    }
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    final message = _message.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = tr('support_err_email'));
      return;
    }
    if (message.isEmpty) {
      setState(() => _error = tr('support_err_msg'));
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _api.createTicket(
        email: email,
        message: message,
        userId: widget.authService.currentUser?.id,
        installId: await _installId(),
      );
      if (!mounted) return;
      _message.clear();
      setState(() => _justSent = true);
      await _load();
    } catch (_) {
      if (mounted) setState(() => _error = tr('support_err_send'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _open(SupportTicketSummary t) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SupportThreadScreen(
        ticketId: t.id,
        api: _api,
        installId: _installId,
        seenStore: _store!,
      ),
    ));
    if (mounted) _load();
  }

  String _statusLabel(String s) => s == 'answered'
      ? tr('status_answered')
      : s == 'closed'
          ? tr('status_closed')
          : tr('status_open');

  Widget _ticketCard(SupportTicketSummary t) {
    final unread = _store?.isUnseen(t) ?? false;
    final prefix = t.lastFromCustomer ? tr('you') : tr('passim_support');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => _open(t),
        title: Row(
          children: [
            Chip(label: Text(_statusLabel(t.status)), visualDensity: VisualDensity.compact),
            const Spacer(),
            Text(timeAgo(t.lastAt), style: const TextStyle(fontSize: 11)),
            if (unread) ...[
              const SizedBox(width: 8),
              Container(
                key: Key('unread_${t.id}'),
                width: 10,
                height: 10,
                decoration: const BoxDecoration(color: DykColors.yellow, shape: BoxShape.circle),
              ),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('$prefix: ${t.lastBody}', maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('help_support'), style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(passimArtwork(context)),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        child: Container(
          decoration: passimScrim(context),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (_loadingList)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_listError != null) ...[
                Text(_listError!),
                TextButton(onPressed: _load, child: Text(tr('retry'))),
                const SizedBox(height: 12),
              ] else if (_tickets.isNotEmpty) ...[
                Text(tr('your_conversations'),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1)),
                const SizedBox(height: 10),
                ..._tickets.map(_ticketCard),
                const SizedBox(height: 18),
                Text(tr('new_message'),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1)),
                const SizedBox(height: 10),
              ],
              if (_justSent) ...[
                Text(tr('message_sent_sub'), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
              ] else
                Text(tr('support_intro'), style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 18),
              TextField(
                key: const Key('support_email_field'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: InputDecoration(labelText: tr('your_email'), border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('support_message_field'),
                controller: _message,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: tr('whats_going_on'),
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  key: const Key('support_send_message'),
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.send),
                  label: Text(_sending ? tr('sending') : tr('send_message')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests, analyze, commit**

```bash
flutter test test/widgets/support_screen_test.dart
flutter analyze lib/screens/support_screen.dart
git add lib/screens/support_screen.dart test/widgets/support_screen_test.dart   # plus lib/services/auth_service.dart only if forTests() was added
git commit -m "feat(support): support screen shows conversations, sends tickets with install_id"
```
Expected: 4 pass, analyzer clean. The two existing call sites compile unchanged (verify with `flutter analyze lib/screens/tabs/profile_tab.dart lib/screens/settings_screen.dart`).

---

### Task 8: Wiring — launch/resume check, notification route, Android isolate

**Files:**
- Modify: `lib/main.dart` — `_DykAppState`: lifecycle observer, launch check, `support:` route.
- Modify: `lib/services/geofence_task_handler.dart` — 5-minute check + notif strings.

**Interfaces:**
- Consumes: `SupportReplyChecker`, `showSupportReplyNotification` (Task 4); `SupabaseSupportApi` (Task 2); `SupportSeenStore` (Task 3); `SupportThreadScreen` (Task 6); `SupportScreen` (Task 7); `tr('support_reply_notif_title')` (Task 5).

- [ ] **Step 1: `main.dart` — observer and checker**

Change the class header:
```dart
class _DykAppState extends State<DykApp> with WidgetsBindingObserver {
```
Add fields next to the other `late`/`final` fields:
```dart
  SupportReplyChecker? _supportChecker;
```
In `initState()`, after `NotificationRouter.pending.addListener(_handleNotificationTap);`:
```dart
    WidgetsBinding.instance.addObserver(this);
```
Add a `dispose` (or extend the existing one) with `WidgetsBinding.instance.removeObserver(this);`.
Add:
```dart
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkSupportReplies();
  }

  Future<void> _checkSupportReplies() async {
    _supportChecker ??= SupportReplyChecker(
      api: SupabaseSupportApi(),
      store: await SupportSeenStore.load(),
      installId: _deviceService.installId,
      notify: ({required ticketId, required body}) => widget.notificationService.showSupportReplyNotification(
        ticketId: ticketId,
        title: tr('support_reply_notif_title'),
        body: body,
      ),
    );
    await _supportChecker!.check();
  }
```
At the end of `_initTelemetry()` (after the existing awaits), add `await _checkSupportReplies();` — launch check runs once telemetry (which guarantees the install id) is done.

Imports to add: `services/support_api.dart`, `services/support_reply_checker.dart`, `services/support_seen_store.dart`, `screens/support_thread_screen.dart`, `screens/support_screen.dart`, and `i18n/i18n.dart` if `tr` is not already imported.

- [ ] **Step 2: `main.dart` — the `support:` route**

In `_handleNotificationTap`, after the `deal` branch:
```dart
    } else if (type == 'support') {
      SupportSeenStore.load().then((store) {
        if (!mounted) return;
        nav.push(MaterialPageRoute(
          builder: (_) => SupportThreadScreen(
            ticketId: id,
            api: SupabaseSupportApi(),
            installId: _deviceService.installId,
            seenStore: store,
          ),
        ));
      });
    }
```
`SupportThreadScreen` pops itself with a snackbar on `SupportNotFound`; that leaves the user where they were, which the spec accepts ("opens the support list, not a crash" — a pop to the previous screen is the no-crash outcome; if the previous screen is not the support list, the snackbar explains). No extra route is needed.

- [ ] **Step 3: Android isolate — strings and the 5-minute check**

In `geofence_task_handler.dart`, add to each language in `_notifStrings`:
```dart
    'support_reply_title': 'Passim Support replied',            // en
    'support_reply_title': 'Soporte de Passim ha respondido',   // es
    'support_reply_title': 'Suport de Passim ha respost',       // ca
    'support_reply_title': 'Passim Support hat geantwortet',    // de
```
Add a field to `GeofenceTaskHandler`:
```dart
  int _tick = 0;
  static const _supportEveryTicks = 25; // 25 × 12 s ≈ 5 min
```
In `_check()`, right after `await prefs.reload();`:
```dart
    _tick++;
    if (_tick % _supportEveryTicks == 0) await _checkSupportReplies(prefs);
```
Add the method (next to `_logReach`):
```dart
  /// Mirror of SupportReplyChecker for the background isolate: plain HTTP
  /// against the same RPC, same SharedPreferences keys, same rule — a staff
  /// reply newer than both the seen and the notified mark gets one
  /// notification. Watermarks are UTC ISO-8601, compared as DateTimes.
  Future<void> _checkSupportReplies(SharedPreferences prefs) async {
    final installId = prefs.getString('anon_install_id');
    if (installId == null || installId.length < 8) return;
    try {
      final res = await http.post(
        Uri.parse('$_supabaseUrl/rest/v1/rpc/support_my_tickets'),
        headers: {
          'apikey': _anonKey,
          'Authorization': 'Bearer $_anonKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'p_install_id': installId}),
      );
      if (res.statusCode != 200) return;
      final list = jsonDecode(res.body);
      if (list is! List) return;
      for (final raw in list) {
        final t = raw as Map<String, dynamic>;
        if (t['last_from_customer'] == true) continue;
        final id = t['id'] as String?;
        final lastAtRaw = t['last_at'] as String?;
        if (id == null || lastAtRaw == null) continue;
        final lastAt = DateTime.parse(lastAtRaw).toUtc();
        DateTime? mark(String key) {
          final v = prefs.getString(key);
          return v == null ? null : DateTime.parse(v).toUtc();
        }
        final seen = mark('support_seen_$id');
        final notified = mark('support_notified_$id');
        if (seen != null && !lastAt.isAfter(seen)) continue;
        if (notified != null && !lastAt.isAfter(notified)) continue;
        final body = (t['last_body'] as String?) ?? '';
        await _notifications.show(
          id.hashCode,
          _ntr(prefs, 'support_reply_title'),
          body.length > 80 ? body.substring(0, 80) : body,
          NotificationDetails(
            android: const AndroidNotificationDetails(
              'support_channel',
              'Support',
              channelDescription: 'Replies from Passim Support',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(),
          ),
          payload: 'support:$id',
        );
        await prefs.setString('support_notified_$id', lastAt.toIso8601String());
      }
    } catch (_) {}
  }
```
`dart:convert` (`jsonEncode`/`jsonDecode`) and `package:http` are already imported in this file (used by `_logReach`) — confirm rather than re-import.

- [ ] **Step 4: Analyze, full test run, commit**

```bash
flutter analyze
flutter test
git add lib/main.dart lib/services/geofence_task_handler.dart
git commit -m "feat(support): check for replies on launch/resume and every ~5 min on Android; route support notifications"
```
Expected: analyzer clean for the whole project; every test passes.

---

### Task 9: Release build and live verification

**Files:**
- Modify: `pubspec.yaml` (`version:`)

- [ ] **Step 1: Version bump**

`pubspec.yaml`: `version: 1.1.0+1` → `version: 1.2.0+2`. Commit: `chore: bump to 1.2.0+2 — in-app support inbox`.

- [ ] **Step 2: Build the Android APK locally**

```bash
cd C:/Users/tilly/palma_app
flutter clean && flutter pub get
flutter analyze
flutter test
flutter build apk --release
```
Expected: `build/app/outputs/flutter-apk/app-release.apk`. Report its size and the exact build output tail. (If signing needs `key.properties` and it is missing, the build falls back to debug signing per `android/app/build.gradle.kts` — say which happened.)

- [ ] **Step 3: Owner — install and test the chain (Android)**

1. Confirm migration 047 is applied (Task 1 Step 4).
2. Install the APK. Open Help & Support → send a ticket → it appears at the top of "Your conversations" with status *Open*.
3. Admin panel (deployed `master`) → Support → the new ticket → reply.
4. App → Help & Support: the card shows the unread dot and "Passim Support: …"; open it → the reply is a left bubble labelled "Passim Support". Reply from the app → the thread shows it; admin shows the ticket back under *New*.
5. Background the app (home button), reply again from admin, wait up to five minutes → notification "Passim Support replied" → tap → the thread opens.
6. Record the outcome in the spec's §9 as a dated line.

- [ ] **Step 4: iOS via Codemagic (owner)**

Push `main` via GitHub Desktop → Codemagic workflow `ios-testflight` → TestFlight. On iOS, verify steps 2–4 above; step 5's background notification is expected **not** to fire (spec §9) — the notification appears on the next app open instead.

- [ ] **Step 5: Commit the verification note**

```bash
git add docs/superpowers/specs/2026-09-25-support-inbox-app-design.md
git commit -m "docs: support inbox verified live on Android"
```

---

## Self-review against the spec

**Spec coverage:**
- §2 one identity path → `installId()` (T3) used by every screen and the checker; `createTicket` carries `install_id` (T2/T7).
- §2 labels "You"/"Passim Support" → `_Bubble` (T6), `_ticketCard` prefix (T7); test asserts no "staff"/"Michelle" text (T6).
- §3 migration 047 → T1, with fallbacks for message-less tickets.
- §4.1 `installId()` → T3. §4.1b `SupportApi` → T2.
- §4.2 list + form, status chips, unread dot, prefix, success copy, loading/error states → T7 (tests cover empty, list, error, send).
- §4.3 thread screen: bubbles, reply box, cap, local append, error keeps text, seen-mark on open, not-found pops → T6 (5 tests).
- §4.4 seen store, pure `unseenTickets` → T3 (7 tests).
- §4.5 notification content/payload, once-per-reply, three check points, tap routing → T4 (checker + notification), T8 (launch/resume, isolate every 25 ticks, `support:` route).
- §4.6 languages → T5 (+ isolate strings in T8).
- §5 failure rows → list error + retry (T7), reply failure keeps text (T6), deleted ticket → pop + snackbar (T6), notification for a gone ticket → same pop (T8 note), background failure silent (T4/T8 catch), missing install id → created on first use (T3).
- §6 testing → T2, T3, T4, T6, T7 unit/widget tests; T1 owner verification; T9 live chain.
- §7 release → T9.
- §8 out of scope: nothing in the plan touches FCM, email, RLS reads, attachments.

**Placeholder scan:** none. Two explicit "check and report" instructions (T6 surface colour, T7 `AuthService.forTests()`) are decisions gated on facts in files the executor can read, each with both outcomes spelled out.

**Type consistency:** `SupportTicketSummary` fields (`id, status, createdAt, lastBody, lastFromCustomer, lastAt, staffCount`) used identically in T3 tests, T4 checker, T7 card. `SupportApi` four methods — same signatures in T2 interface, T4/T6/T7 fakes, T7 `createTicket` call. `SupportSeenStore.watermarks/markSeen/markNotified/isUnseen/load` — T3 definition, T4 checker (`watermarks`, `markNotified`), T6 (`markSeen`), T7 (`isUnseen`, `load`), T8 (`load`). `SupportReplyChecker` constructor named params match T4 and T8. `showSupportReplyNotification({ticketId, title, body})` — T4 definition, T8 call. Prefs keys `support_seen_<id>` / `support_notified_<id>` and UTC ISO values — T3 store and T8 isolate.
