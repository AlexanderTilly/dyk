# Support Inbox in the App — Design Spec (sub-project C of Michelle v2)

**Date:** 2026-09-25
**Status:** Awaiting review
**Scope:** The Passim Flutter app (`palma_app`) shows a customer's support conversations, lets them reply, and notifies them when Passim Support has answered. Builds on sub-project A (migrations 045/046, admin thread — in production 2026-09-25).

| | Sub-project | State |
|---|---|---|
| A | Support thread + admin reply | done, deployed (admin on `master`) |
| B | Michelle answers tickets with an approval gate | not started |
| **C** | **In-app inbox** *(this spec)* | — |

## 1. Problem

Since A, staff can answer a ticket in the admin panel and the answer is stored in `support_messages`. The app cannot show it: `support_screen.dart` only inserts a ticket and says "we'll get back to you by email" — which nobody does. Until the app shows the thread, every reply written in admin is invisible to the customer.

## 2. Decisions made with the owner

- **One identity path: `install_id` for everyone.** The app always sets `install_id` (the device's existing `anon_install_id`) on new tickets and always reads through the `install_id` RPCs, signed in or not. Threads follow the device. Cross-device history for signed-in users is a later addition (046's owner-select policy already allows it) and changes nothing built here.
- The customer sees staff and Michelle replies as **"Passim Support"** — never a name, never "Michelle". Their own messages show as "You".
- Delivery is **in-app + local notification**; no email.
- A closed ticket can still be replied to; 045's trigger reopens it.

## 3. Data / API — migration `047_support_my_tickets.sql`

One new RPC, `security definer`, `search_path = public`, `revoke … from public`, `grant execute … to anon, authenticated`, idempotent (`create or replace`):

`support_my_tickets(p_install_id text) → jsonb` — an array of the device's tickets, newest first:
`{ id, status, created_at, last_body, last_from_customer, last_at, staff_count }` where `last_*` describe the most recent message and `staff_count` is the number of non-customer messages. Raises `not found` for a null/short `p_install_id` (same rule as `support_thread`). Returns `[]` when the device has no tickets.

The existing RPCs are used unchanged: `support_thread(p_ticket_id, p_install_id)` for one conversation, `support_reply(p_ticket_id, p_install_id, p_body)` to answer.

**Ticket creation** (`support_screen.dart`) adds `install_id` to the insert. The `insert` policy on `support_tickets` (026) already allows anon/authenticated inserts with any columns.

## 4. App

### 4.1 Identity

`DeviceProfileService` exposes `Future<String> installId()` — the same `anon_install_id` it already stores in SharedPreferences, created on first use. Everything in this spec reads it from there; nothing else generates ids.

### 4.1b Network boundary — `SupportApi` (new)

One small class wraps every call the feature makes: `listTickets(installId)` → `support_my_tickets`, `thread(ticketId, installId)` → `support_thread`, `reply(ticketId, installId, body)` → `support_reply`, and `createTicket(email, message, userId, installId)` → the `support_tickets` insert. Screens and the checker depend on this interface, never on `Supabase.instance` directly, so widget and logic tests inject a fake. The Android isolate has its own HTTP path (4.5) and does not use this class.

### 4.2 Support screen (`support_screen.dart`, rebuilt)

Two sections in one scrolling view:

1. **Your conversations** — shown only when `support_my_tickets` returns at least one ticket. A card per ticket: status chip (*Open* for `new`, *Answered*, *Closed*), the last message truncated to two lines with a "You:" / "Passim Support:" prefix, time ago, and an unread dot when a staff reply is newer than the device's last-seen mark (4.4). Tap → thread screen.
2. **New message** — the existing form (email + message + send), unchanged in behaviour except that the insert now carries `install_id`, and after sending the screen returns to the list with the new ticket on top instead of the "we'll get back to you by email" page. The success copy becomes "Message sent — you'll see the reply here."

Loading and error states: a spinner while the list loads; on failure an inline line "Couldn't load your conversations" with a retry, and the new-message form still works.

### 4.3 Thread screen (`support_thread_screen.dart`, new)

- App bar: "Passim Support" and the status chip.
- Messages oldest first as bubbles: the customer's on the right ("You"), everything else on the left ("Passim Support"). Time ago under each.
- Reply box pinned at the bottom: multiline field + send. Empty/whitespace refused client-side; 4000-char cap mirrors the DB. On send: `support_reply` → the message is appended locally and the list is refetched on return. On failure the text stays and an inline error shows.
- Opening the thread marks it seen (4.4).

### 4.4 "Unseen reply" tracking — `SupportSeenStore` (new, pure + SharedPreferences)

Per ticket, the app stores the `last_at` of the newest **staff** message the user has seen (`support_seen_<ticket_id>` → ISO timestamp). A ticket has an unseen reply when `!last_from_customer && last_at > seen`. Opening the thread sets `seen = last_at`. The decision logic (`unseenTickets(list, seenMap)`) is a pure function so it can be unit-tested without a device.

### 4.5 Notifications

A staff reply produces one local notification per ticket, *"Passim Support replied"* with the first ~80 characters of the reply, payload `support:<ticket_id>`. It is shown by whichever check runs first; a ticket is notified at most once per new reply (`support_notified_<ticket_id>` → `last_at`).

Three check points, all calling `support_my_tickets(install_id)` and the same pure logic:

| When | Where | Platform |
|---|---|---|
| App launch and every resume (`AppLifecycleState.resumed`) | a `SupportReplyChecker` invoked from the app shell | Android + iOS |
| Every ~5 minutes while the foreground service runs | `geofence_task_handler.dart`, via its existing anon-key HTTP client (`/rest/v1/rpc/support_my_tickets`), counting ticks (25 × 12 s) | Android |
| Notification tap | `NotificationRouter` payload `support:<id>` → `main.dart` opens the thread screen; unknown id → the support list | Android + iOS |

The Android isolate has its own translation table for notification copy (as it does for hotspots); the new strings are added there in all four languages.

### 4.6 Language

New keys in `i18n.dart` for en, es, ca, de: `your_conversations`, `passim_support`, `you`, `status_open`, `status_answered`, `status_closed`, `reply`, `send_reply`, `reply_placeholder`, `no_conversations_yet`, `couldnt_load_conversations`, `retry`, `message_sent_sub` (rewritten), `support_reply_notif_title`.

## 5. Failure behaviour

| Failure | Behaviour |
|---|---|
| No network on the support screen | Inline error + retry; the new-message form still works (its own insert fails with the existing error copy) |
| `support_reply` fails | Text kept, inline error; nothing appended locally |
| Ticket deleted in admin while open in the app | `support_thread` raises `not found` → "This conversation is no longer available", back to the list |
| Notification for a ticket that no longer exists | Opens the support list, not a crash |
| Background check fails (no network, RPC error) | Silent; next tick tries again |
| `install_id` missing (first launch race) | Generated on first use — there is no state without it |

## 6. Testing

- **Pure logic**: `unseenTickets` and the "notify at most once per reply" rule — unit tests in `test/services/`.
- **Widget tests**: the thread screen renders bubbles on the correct sides with "You" / "Passim Support"; the reply button is disabled on empty input; the list card shows the unread dot when the logic says so. Network calls are behind a small `SupportApi` interface so tests inject a fake.
- **Migration 047**: applied by the owner in the SQL editor; verified by calling it from the app and by Michelle's read role listing the function.
- **End to end (manual, the owner)**: from a debug build, send a ticket → it appears in admin → reply from admin → open the app: unread dot, thread shows the reply; background the app on Android, reply again from admin, wait up to five minutes → notification → tap → thread.

## 7. Release

`pubspec.yaml` version bump; Android APK built locally, iOS via Codemagic → TestFlight — the project's existing routine. The owner performs the store-side steps.

## 8. Out of scope

- Michelle writing replies (B).
- Cross-device history for signed-in users (later; 046 makes it possible).
- Push notifications via FCM/APNs (no provider in the app; the local-notification checks above are the v1 answer).
- Attachments, read receipts, typing indicators.
- Email delivery.

## 9. Known gaps this spec accepts

- iOS users are notified only when they open the app; there is no background poll on iOS.
- Android notifications depend on the foreground service being enabled (background location permission granted). Without it, iOS behaviour applies.
- A reinstall or a new device starts with no history.
