# Michelle Answers Support Tickets — Design Spec (Michelle v2, sub-project B)

**Date:** 2026-09-28
**Status:** Approved
**Scope:** Michelle's first write capability. She finds unanswered Passim support tickets, reads them (using data she already has read access to), proposes a reply out loud, and — only after the owner's explicit spoken approval — sends it. Builds on sub-project A (`support_messages`, live in production) and reuses the identity rule sub-projects A/C already established: a reply is never attributed to "Michelle" or "staff" in its content, only internally via the `author` column.

| | Sub-project | Repos | State |
|---|---|---|---|
| A | Support thread + admin reply | `palma_app` (migration), `dyk-admin` | done, live |
| C | In-app inbox | `palma_app` (Flutter) | code complete, owner verifying |
| **B** | **Michelle answers tickets** *(this spec)* | `michelle`, `palma_app` (migration) | — |

## 1. Problem

Three tickets sit unanswered in Passim right now. Michelle can already read them (proven live, 2026-09-28 — she found and correctly described all three via her existing `escalate` → `query` path) but has no way to act: her only database role, `michelle_ro`, is `SELECT`-only by design — that guarantee is the entire safety argument Michelle v1 was built on, and this spec must not weaken it for the read side.

## 2. Decisions made with the owner

- **Approval is conversational, not a UI button.** The owner said "yes, send it" (or similar) as a spoken/typed reply to Michelle's proposal; there is no new console UI element for this. This is a deliberate risk the owner chose with the tradeoff explained — see §4 for how the code narrows what that risk can actually do.
- **One ticket at a time.** She proposes for one ticket, waits for the owner's answer, only then moves to the next. Never several proposals in flight at once — removes any ambiguity about which "yes" belongs to which draft.
- **On rejection, she drops it.** No automatic "what should I say instead?" follow-up. The owner drives what happens next — retry, a different angle, or move to the next ticket — entirely through the normal conversation.
- **Discovery both ways**: a `support_pending` figure appears in `daily_briefing` (a count, so the owner is reminded without asking), and the owner can ask for it directly ("check the support tickets").
- **Simple-vs-holding-reply is judgment, not a code path.** Whether a ticket gets a real answer or a "we've seen it, working on it" holding reply is entirely what Michelle decides to propose — the owner's review of the proposal is the check on that judgment, not a separate mechanism.

## 3. The safety design

The single most important property of this feature: **Michelle can never send text the owner did not already hear or see.** This is enforced structurally, not by prompting her to be careful.

- `propose_support_reply(ticket_id, body)` writes nothing to any database. It stores the proposed body in a single in-memory slot on the server (`PendingReplyStore`) and returns it so it is spoken/shown. Because only one ticket is worked at a time (§2), the store holds at most one pending draft — proposing again simply replaces it.
- `send_support_reply(ticket_id)` — **note what is absent: there is no `body` parameter.** Its JSON schema gives the model no way to submit new text at send time. The tool reads the single pending draft, confirms its `ticket_id` matches the one the model is asking to send, and inserts exactly that stored body. If nothing is pending, or the ticket id doesn't match, it refuses with a clear error rather than guessing.
- What is *not* structurally guaranteed, and was an explicit, informed tradeoff (§2): that the owner's reply genuinely means "yes, send this specific thing." Michelle's system prompt (§7) states the rule in the strongest terms available to a prompt, but a misheard or ambiguous confirmation is a real, accepted residual risk.
- The write role itself (§5) can perform exactly one kind of statement — an `insert` into `support_messages` with `author = 'michelle'` — and nothing else. It cannot `select`, `update`, or `delete`, and it cannot insert as any other author. Even a compromised or buggy tool implementation on the write path cannot do more than append one more such row.

## 4. New tools (`michelle` repo)

| Tool | Tier | Reads/writes |
|---|---|---|
| `support_pending` | fast | reads via the existing `michelle_ro` Passim connection |
| `propose_support_reply` | broad | reads nothing new; writes only to the in-memory `PendingReplyStore` |
| `send_support_reply` | broad | writes via the new `michelle_rw` Passim connection |

**Why `propose`/`send` are broad-tier only:** drafting a customer-facing reply is real reasoning — it may mean reading a hotspot's coordinates to judge whether a "wrong location" complaint is right, or weighing whether an issue is simple enough to answer outright. That belongs to Opus, not a fast Haiku pass, and sending must never be reachable from the fast path at all.

### 4.1 `support_pending`

```
Tickets awaiting a reply — status 'new' means the newest message is from the
customer and nobody (staff or Michelle) has answered yet. Oldest first, so
the queue is worked in the order complaints arrived.
```

Returns figures (`pending count`) and `rows`: one per ticket — `ticket_id`, `email`, `latest customer message` (truncated similarly to the app's own notification truncation, 200 chars), `created_at`, `days_open`. Registered in the `fast` array in `index.ts` alongside the five existing briefings, so it is automatically included in `daily_briefing`'s composite (§2's "both ways" requirement is satisfied by the existing composition mechanism — no special-casing).

### 4.2 `propose_support_reply`

Input: `{ ticket_id: string, body: string }`. Validates `body` is 1–4000 characters (mirrors the DB check `support_messages` already enforces, so a proposal that would later fail to insert is caught immediately instead of at send time). Stores `{ ticketId, body, proposedAt }` in `PendingReplyStore`, replacing any earlier pending draft. Returns the body as `text` (so it is naturally spoken) plus a note reminding the model of the send-only-this-ticket rule (belt-and-braces alongside the system prompt).

### 4.3 `send_support_reply`

Input: `{ ticket_id: string }` — no body field exists in the schema. Logic:

```
pending = pendingReplyStore.get()
if pending is null → error "Nothing has been proposed yet — propose a reply first."
if pending.ticketId !== ticket_id → error "The pending draft is for a different ticket."
insert into support_messages (ticket_id, author, body) values (pending.ticketId, 'michelle', pending.body)
pendingReplyStore.clear()
→ figure "sent", note confirming which ticket
```

The insert runs on the new `michelle_rw` connection (§5). 045's existing `support_messages_set_status` trigger fires automatically and sets the ticket's status to `'answered'` — no new trigger is needed.

## 5. New migration `048_michelle_support_writer.sql` (`palma_app`)

A second Postgres role, separate from `michelle_ro`, narrower than any role in this project so far:

```sql
create role michelle_rw login password 'REPLACE_ME' nosuperuser nocreatedb nocreaterole noinherit;
alter role michelle_rw set statement_timeout = '8s';

grant insert on public.support_messages to michelle_rw;

drop policy if exists michelle_rw_insert on public.support_messages;
create policy michelle_rw_insert on public.support_messages
  for insert to michelle_rw
  with check (author = 'michelle' and author_user_id is null);
```

Deliberately absent: any `select`, `update`, or `delete` grant; any grant on `support_tickets` or any other table; `usage` on the schema is required for the insert to resolve the table but nothing beyond it. `michelle_rw` cannot read the row it just inserted, cannot see any other table, and cannot touch `support_tickets.status` directly (only the existing trigger can, and only in response to the one insert shape this role is allowed to make).

The plan's implementation task must include the integration test this project has treated as load-bearing since Michelle v1: attempt every write this role should be refused (`select`, `update`, `delete`, insert with `author <> 'michelle'`, insert with a non-null `author_user_id`) and confirm each is rejected, alongside confirming the one permitted shape succeeds.

## 6. `michelle` repo — connection and state plumbing

- `config.ts` gains an optional `MICHELLE_PASSIM_WRITE_DB_URL` (palmacrew is untouched by this feature — no write role there). Optional exactly like the existing read URLs: if unset, the write tools report "not configured" rather than crashing the server, matching `DbUnavailable`'s existing pattern.
- A new, separate `WriteDb` interface — **not** an extension of the existing `Db` interface, and not a generic `execute(sql)` method. Its only method is `insertSupportReply(ticketId: string, body: string): Promise<{ id: string }>`, hardcoded to the one parameterized statement in §4.3. This keeps the blast radius of "Michelle can write" to exactly the one operation this spec describes — a free-write escape hatch is explicitly out of scope, now and later.
- `ToolContext` gains two fields: `writeDb: WriteDb` and `pendingReply: PendingReplyStore`. `PendingReplyStore` is a small, pure-ish class (`propose`, `get`, `clear`) — single mutable slot, not a map, matching §2's one-at-a-time rule exactly. It requires no persistence (SharedPreferences-equivalent) — if the server restarts mid-approval, the pending draft is gone and Michelle proposes again, which is the correct, safe behaviour.

## 7. System prompt additions

Appended to `brain.ts`'s `SYSTEM` string, after the existing rules:

```
- You can now propose and send replies to Passim support tickets. Read the ticket for yourself before proposing anything — never invent what a customer said.
- Never send without proposing first in this same conversation, and never send unless the owner's most recent reply is a clear, specific yes to that exact proposal. A vague or ambiguous reply is a no — ask again rather than guess.
- One ticket at a time. If the owner says no, drop it — do not re-propose automatically or ask what to say instead.
- The reply's content is written as "Passim Support" — never mention Michelle, AI, or being an assistant inside the reply text itself.
```

## 8. Failure behaviour

| Failure | Behaviour |
|---|---|
| `send_support_reply` with nothing proposed | Tool returns an error; she says she has nothing to send yet |
| `send_support_reply` for a different ticket than what's pending | Tool refuses; she clarifies which ticket she meant |
| Write DB unreachable / `MICHELLE_PASSIM_WRITE_DB_URL` unset | Tool reports unavailable, same shape as `DbUnavailable`; she says she can't send right now |
| Owner's reply is ambiguous | Per the prompt (§7), treated as no — she asks again rather than sending |
| Proposed body outside 1–4000 chars | `propose_support_reply` refuses before anything is stored; she is told to shorten/lengthen |
| Server restarts with a draft pending | Draft is lost (in-memory only); she proposes again if asked |

## 9. Testing

- `PendingReplyStore`: pure unit tests — propose/get/clear, replacing an existing draft, mismatch on `send`.
- `support_pending`: same fixture pattern as the existing five briefings (fake `db.select`).
- `propose_support_reply`: stores correctly, validates length, never touches `writeDb`.
- `send_support_reply`: the four cases in §8 that matter for this tool, plus the happy path (fake `writeDb`, confirms it is called with the *stored* body regardless of what the tool's input contained — the schema already prevents a body param, but the test should also assert the implementation never reads one if present).
- **The role integration test (§5)** is the load-bearing test for this whole sub-project, in the same sense `db.int.test.ts` was for Michelle v1: it is what makes "Michelle can only do this one thing" a fact the database enforces rather than a hope.
- Manual, live (owner): propose a reply to a real pending ticket, approve it, confirm it appears in the admin thread (A) and, once installed, the app (C); separately, say no to a proposal and confirm nothing was sent.

## 10. Out of scope

- Any UI change to the console (§2 — the owner's explicit choice).
- Any write capability beyond `support_messages` inserts — no ticket status changes she initiates directly, no deletes, no edits to a sent reply.
- PalmaCrew — this sub-project only touches Passim's support tables.
- Batch/multi-ticket proposals.
- Persisting a pending draft across a server restart.

## 11. Known gap this spec accepts

The approval step ultimately rests on the model correctly judging that the owner's last utterance was an unambiguous yes to the specific thing just proposed. §3 states plainly what is and is not structurally guaranteed; this residual is the owner's informed, explicit choice (§2), not an oversight.
