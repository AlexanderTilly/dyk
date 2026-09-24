# Support Thread — Design Spec (sub-project A of Michelle v2)

**Date:** 2026-09-24
**Status:** Awaiting review
**Scope:** Passim support tickets become conversations, readable and answerable from the admin panel. This is sub-project **A** of three:

| | Sub-project | Repos | Depends on |
|---|---|---|---|
| **A** | Support thread + admin reply *(this spec)* | `palma_app` (migration), `dyk-admin` | — |
| B | Michelle answers tickets with an approval gate | `michelle` | A's table |
| C | In-app inbox in the Passim app | `palma_app` (Flutter) | A's table and RPCs |

B and C each get their own spec. Nothing in A depends on them, and A is useful on its own: staff can reply in admin the day the migration runs.

---

## 1. Problem

Today a support ticket is a one-way message. The app inserts a row in `support_tickets` (email, message, optional `user_id`); the admin panel lists it, offers a `mailto:` link, and a "Mark handled" button. The reply — if any — lives in someone's mail client. Nothing in the system knows a ticket was answered, what was said, or by whom. The app cannot show a reply, and Michelle (B) has nothing to write into.

## 2. Decisions already made with the owner

- A ticket is a **conversation**: both sides may write several times.
- Delivery is **in-app** (C), not email. Email is "solved later" and is out of scope here; the `mailto:` link stays as a manual fallback.
- The customer sees every reply as from **"Passim Support"**, regardless of who wrote it. Internally, the author is always recorded — and Michelle is a distinct author kind so machine-written text is always identifiable afterwards.
- Guests (no account) must be able to receive replies **on the same device**, via the device's `install_id`.

## 3. Data model — migration `supabase/migrations/045_support_thread.sql`

### 3.1 New table `support_messages`

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK, `gen_random_uuid()` | |
| `ticket_id` | `uuid` → `support_tickets(id)` on delete cascade | |
| `author` | `text` check in (`'customer'`, `'staff'`, `'michelle'`) | who wrote it |
| `author_user_id` | `uuid` → `auth.users(id)` on delete set null | the admin, for `staff`; null otherwise |
| `body` | `text` not null, check `length(body) between 1 and 4000` | |
| `created_at` | `timestamptz` not null default `now()` | |

Index on `(ticket_id, created_at)`.

### 3.2 Changes to `support_tickets`

- `install_id text null` — the device id the app already generates (`device_profile_service.dart`). Set by the app in C; null until then.
- `status` check widens from (`new`, `closed`) to (`new`, `answered`, `closed`). Existing rows keep their values.
- `message` stays untouched. The app keeps writing it until C changes the app; the backfill (3.5) makes it redundant for reading.

### 3.3 Status is derived, not managed

A trigger `support_messages_set_status` **after insert** on `support_messages`:

- `author = 'customer'` → ticket `status := 'new'` (this also reopens a `closed` ticket — a customer writing again is a new request).
- `author in ('staff', 'michelle')` → `status := 'answered'`.

`updated_at` on the ticket follows via the existing `set_updated_at` trigger (the status update fires it). Staff may still set `closed` explicitly (admin "Close" button) and `new` (admin "Reopen").

### 3.4 Access (RLS)

`support_messages` has RLS enabled. Policies:

| Who | May |
|---|---|
| Admin (`is_admin()`) | select, insert, update, delete — everything, as on `support_tickets` today |
| Signed-in customer | select and insert where the parent ticket's `user_id = auth.uid()`; inserts must have `author = 'customer'` and `author_user_id is null` (enforced in the policy's `with check`) |
| Guest | nothing directly — see the RPCs below |
| `michelle_ro` (if the role exists) | select — a `michelle_read` policy, created inside a `do $$ … if exists (select 1 from pg_roles where rolname = 'michelle_ro') … $$` block so the migration runs on a database where Michelle's role was never created |

**Guest RPCs** (`security definer`, `search_path = public`, granted to `anon, authenticated`):

- `support_thread(p_ticket_id uuid, p_install_id text)` → the ticket (id, status, created_at) and its messages, **only if** `support_tickets.install_id = p_install_id` for that ticket. Otherwise raises `not found`.
- `support_reply(p_ticket_id uuid, p_install_id text, p_body text)` → inserts a `customer` message under the same check; returns the new message id.

Knowing an `install_id` grants access to that device's tickets. The id is a random uuid that never leaves the device except in these calls — the same trust level as a magic link. That is the accepted price of replying to guests at all. Signed-in users do not need the RPCs (RLS covers them) but may use them.

Michelle's **write** access is deliberately **not** part of this migration. B adds a separate role with `insert` on `support_messages` only, with `author = 'michelle'` enforced by its policy.

### 3.5 Backfill

For every existing ticket, insert one `support_messages` row: `author = 'customer'`, `body = message`, `created_at = ticket.created_at`. Guarded so re-running the migration does not duplicate (`where not exists (select 1 from support_messages m where m.ticket_id = t.id)`).

The whole migration is idempotent: `create table if not exists`, `add column if not exists`, `drop policy if exists` before each `create policy`, `create or replace function`, `drop trigger if exists`.

## 4. Admin panel — `dyk-admin`

### 4.1 Behaviour

`SupportPage` stays the list. Each ticket card keeps its header (email, ACCOUNT badge, time ago) and gains:

- **The thread**, oldest first: for each message the author label — `Customer`; for `staff` **"You"** when `author_user_id` is the signed-in admin, otherwise **"Staff"** (the panel's client cannot read other admins' emails from `auth.users`, and A does not add a display-name column); `Michelle` with a distinct badge — the body (pre-wrap), and time ago. The customer's original message is the first row (hence the backfill), so the card no longer renders `ticket.message` separately.
- **The reply box**: a textarea and a *Send reply* button. Sending inserts `{ ticket_id, author: 'staff', author_user_id: <current user id>, body }`. The trigger sets the ticket to `answered`; the client updates the local list to match without a refetch. Empty or whitespace-only replies are refused client-side; the 4000-char limit is shown as a counter (the panel already has a counter pattern for ElevenLabs).
- **Filters** become *New (n) / Answered (n) / Closed (n) / All*. The sidebar count (`onCountChange`) still reports `new` only.
- Buttons: *Close* (was "Mark handled") on `new` and `answered`; *Reopen* on `closed`; *Delete* unchanged. The `mailto:` link stays.

### 4.2 Structure

- `src/pages/SupportPage.tsx` — modified: loads tickets and, in a second query, all messages for the loaded tickets (`in ticket_ids`), groups them per ticket, renders `SupportThread` per card.
- `src/pages/support/SupportThread.tsx` — new: props `{ ticket, messages, currentUserId, onSent(message) }`; renders the thread and the reply box; owns the insert.
- `src/pages/support/threads.ts` — new, pure: `groupByTicket(messages)`, `authorLabel(message, currentUserId)` → `'Customer' | 'You' | 'Staff' | 'Michelle'`, `statusLabel(status)`. Testable without a DOM.
- Types: `SupportTicket.status` widens; new `SupportMessage` type.

No new runtime dependencies.

## 5. Failure behaviour

| Failure | Behaviour |
|---|---|
| Insert fails (network, RLS) | Reply box keeps the text, shows an inline error, does not mark the ticket answered |
| Messages query fails | Cards render with an inline "could not load thread" line; list still works |
| Ticket deleted while a reply is typed | Insert fails on the FK; same inline error |
| Migration re-run | No duplicates, no errors (idempotent by construction) |
| Guest RPC with wrong `install_id` | `not found` — no information about whether the ticket exists |

## 6. Testing

- **Migration**: applied by the owner in Supabase → SQL Editor (as every Passim migration). Verified by (a) the panel showing the backfilled thread for the one real ticket, and (b) Michelle's read role listing `support_messages` — she is the independent witness that the row and the `answered` status landed.
- **`threads.ts`**: vitest unit tests for grouping, author labels (including the `michelle` case), and status labels.
- **`SupportThread`**: one render test with `jsdom` + `@testing-library/react` (two dev dependencies to add): renders authors in order with the Michelle badge, refuses an empty reply, and calls the injected insert with `author: 'staff'` on submit. The Supabase client is passed in (or mocked at the module boundary) so the test never touches the network.
- **Manual, end to end**: after the migration, reply to the real ticket ("the hotspot el corte ingles is wrongly located") from the panel; confirm the thread renders, the tab count moves from *New* to *Answered*, and Michelle can read the reply.

## 7. Out of scope (belongs to B and C)

- Michelle writing replies, the approval gate, her write role (B).
- The app showing the thread, setting `install_id` on new tickets, local notifications on new replies (C).
- Email delivery of replies ("solved later").
- Attachments, read receipts, assignment of tickets to staff.

## 8. Known gaps this spec accepts

- Until C ships, **no customer sees any reply**. Staff replies accumulate in the thread; the customer's only channel remains the `mailto:` fallback used manually.
- Guests who reinstall the app or change device lose their thread (new `install_id`).
- The customer-facing name "Passim Support" is C's rendering decision; A stores the true author.
