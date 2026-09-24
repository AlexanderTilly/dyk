# Support Thread (Michelle v2 — sub-project A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Passim support tickets become conversations: a `support_messages` table with derived ticket status, guest access by `install_id`, and a thread + reply box in the admin panel.

**Architecture:** One idempotent SQL migration in `palma_app` adds the table, trigger, RLS and two guest RPCs, and backfills existing tickets. In `dyk-admin`, a pure `threads.ts` module holds the grouping/labelling logic, a `SupportThread` component renders one thread with a reply box (insert injected as a prop so it is testable), and `SupportPage` loads tickets + messages and composes them.

**Tech Stack:** Postgres/Supabase (SQL, plpgsql, RLS), React 19 + TypeScript 6 + Vite 8, vitest 5, `@testing-library/react` + `jsdom` (added), lucide-react, `@supabase/supabase-js` 2.

**Spec:** `C:/Users/tilly/palma_app/docs/superpowers/specs/2026-09-24-support-thread-design.md` (read it first; this plan argues from it).

## Global Constraints

- **Two repos, two commit streams.** Task 1 commits in `C:/Users/tilly/palma_app` (branch `main`); Tasks 2–5 commit in `C:/Users/tilly/dyk-admin` (branch `master`, **npm**, not pnpm). Commit only the files each task names — `palma_app` has unrelated untracked files (`design/city_headers/`, `supabase/.temp/`) that must never be added. Never push: the owner pushes via GitHub Desktop.
- **Author kinds are exactly** `'customer' | 'staff' | 'michelle'`. Ticket statuses are exactly `'new' | 'answered' | 'closed'`.
- **Status is derived by trigger**: customer message → `new` (reopens closed), staff/michelle message → `answered`. Admin may still set `closed`/`new` explicitly.
- **Reply body**: 1–4000 characters after trim, enforced in the DB check, the RPC, and the UI (`REPLY_MAX_CHARS = 4000`).
- **Customer-facing author name is C's concern.** A stores the true author. The guest RPC exposes only `from_customer: boolean`, never the word "michelle".
- **Admin labels**: `Customer`; `You` when `author_user_id` equals the signed-in admin; otherwise `Staff`; `Michelle` with a distinct badge.
- **Michelle's write access is NOT in this plan** (B). Her read role gets a `michelle_read` select policy on `support_messages` only if the role exists.
- **dyk-admin TypeScript settings**: `verbatimModuleSyntax` (use `import type` for types), `erasableSyntaxOnly` (no enums), `noUnusedLocals`/`noUnusedParameters` — every import and variable must be used.
- **Tests never touch the network.** `SupportThread` receives `insertMessage` as a prop; tests pass a `vi.fn()`.
- **The migration is applied by the owner** in Supabase → SQL Editor (project `jqykkyhoxpykhixwgwyw`). It must be idempotent: re-running produces no errors and no duplicate rows.
- **Delivery to customers is out of scope** (C for in-app, email "later"); the `mailto:` link stays in the admin card.

---

## File Structure

```
palma_app/
└── supabase/migrations/045_support_thread.sql      table, trigger, RLS, RPCs, backfill

dyk-admin/
├── package.json                                     + jsdom, @testing-library/react (dev)
└── src/pages/
    ├── SupportPage.tsx                              MODIFIED: loads tickets + messages, filters, composes SupportThread
    └── support/
        ├── threads.ts                               pure: types, groupByTicket, authorLabel, statusLabel, replyProblem
        ├── threads.test.ts
        ├── SupportThread.tsx                        one thread + reply box; insert injected
        └── SupportThread.test.tsx                   jsdom render test
```

---

### Task 1: Migration `045_support_thread.sql`

**Files:**
- Create: `C:/Users/tilly/palma_app/supabase/migrations/045_support_thread.sql`

**Interfaces:**
- Produces: table `public.support_messages(id, ticket_id, author, author_user_id, body, created_at)`; columns `support_tickets.install_id text`, `support_tickets.status in ('new','answered','closed')`; trigger `support_messages_set_status`; RPCs `support_thread(uuid, text) → jsonb`, `support_reply(uuid, text, text) → uuid`. Tasks 2–5 read/insert `support_messages` with exactly these column names.

- [ ] **Step 1: Write the migration**

```sql
-- 045_support_thread.sql — support tickets become conversations.
-- Idempotent: safe to re-run after a migration adds tables or after a partial run.
-- Run in Supabase → SQL Editor as the default (postgres) user.

-- ------------------------------------------------------------
-- 1. Ticket changes: device id for guests, wider status set
-- ------------------------------------------------------------
alter table public.support_tickets
  add column if not exists install_id text;

-- The inline check on the original column was auto-named <table>_<column>_check.
alter table public.support_tickets drop constraint if exists support_tickets_status_check;
alter table public.support_tickets
  add constraint support_tickets_status_check
  check (status in ('new', 'answered', 'closed'));

-- ------------------------------------------------------------
-- 2. The thread
-- ------------------------------------------------------------
create table if not exists public.support_messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.support_tickets(id) on delete cascade,
  author text not null check (author in ('customer', 'staff', 'michelle')),
  author_user_id uuid references auth.users(id) on delete set null,
  body text not null check (length(body) between 1 and 4000),
  created_at timestamptz not null default now()
);

create index if not exists support_messages_ticket_idx
  on public.support_messages (ticket_id, created_at);

-- ------------------------------------------------------------
-- 3. Status is derived from the last message, never managed by hand.
--    security definer: a customer has no update right on tickets, yet
--    their message must still flip the status.
-- ------------------------------------------------------------
create or replace function public.support_messages_set_status()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update public.support_tickets
     set status = case when new.author = 'customer' then 'new' else 'answered' end
   where id = new.ticket_id;
  return new;
end $$;

drop trigger if exists support_messages_set_status on public.support_messages;
create trigger support_messages_set_status
  after insert on public.support_messages
  for each row execute function public.support_messages_set_status();

-- ------------------------------------------------------------
-- 4. Access
-- ------------------------------------------------------------
alter table public.support_messages enable row level security;

drop policy if exists support_messages_admin_all on public.support_messages;
create policy support_messages_admin_all on public.support_messages
  for all using (public.is_admin()) with check (public.is_admin());

-- A signed-in customer reads and writes their own threads; their inserts
-- are always 'customer' and carry no author_user_id.
drop policy if exists support_messages_customer_select on public.support_messages;
create policy support_messages_customer_select on public.support_messages
  for select to authenticated
  using (exists (
    select 1 from public.support_tickets t
    where t.id = ticket_id and t.user_id = auth.uid()
  ));

drop policy if exists support_messages_customer_insert on public.support_messages;
create policy support_messages_customer_insert on public.support_messages
  for insert to authenticated
  with check (
    author = 'customer' and author_user_id is null
    and exists (
      select 1 from public.support_tickets t
      where t.id = ticket_id and t.user_id = auth.uid()
    )
  );

-- Michelle's read-only role (created by the michelle project) — only if it exists,
-- so this migration also runs on a database where Michelle was never set up.
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'michelle_ro') then
    execute 'drop policy if exists michelle_read on public.support_messages';
    execute 'create policy michelle_read on public.support_messages for select to michelle_ro using (true)';
  end if;
end $$;

-- ------------------------------------------------------------
-- 5. Guest access by install_id. Knowing an install_id grants access to
--    that device's tickets — the same trust as a magic link. The id never
--    leaves the device except in these two calls.
-- ------------------------------------------------------------
create or replace function public.support_thread(p_ticket_id uuid, p_install_id text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v jsonb;
begin
  if p_install_id is null or length(p_install_id) < 8 then
    raise exception 'not found';
  end if;
  select jsonb_build_object(
           'id', t.id,
           'status', t.status,
           'created_at', t.created_at,
           'messages', coalesce((
             select jsonb_agg(jsonb_build_object(
                      'id', m.id,
                      'from_customer', m.author = 'customer',
                      'body', m.body,
                      'created_at', m.created_at
                    ) order by m.created_at)
             from public.support_messages m where m.ticket_id = t.id
           ), '[]'::jsonb)
         )
    into v
    from public.support_tickets t
   where t.id = p_ticket_id and t.install_id = p_install_id;
  if v is null then
    raise exception 'not found';
  end if;
  return v;
end $$;
revoke all on function public.support_thread(uuid, text) from public;
grant execute on function public.support_thread(uuid, text) to anon, authenticated;

create or replace function public.support_reply(p_ticket_id uuid, p_install_id text, p_body text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if p_install_id is null or length(p_install_id) < 8 then
    raise exception 'not found';
  end if;
  if p_body is null or length(trim(p_body)) not between 1 and 4000 then
    raise exception 'body must be 1-4000 characters';
  end if;
  if not exists (
    select 1 from public.support_tickets t
    where t.id = p_ticket_id and t.install_id = p_install_id
  ) then
    raise exception 'not found';
  end if;
  insert into public.support_messages (ticket_id, author, body)
  values (p_ticket_id, 'customer', trim(p_body))
  returning id into v_id;
  return v_id;
end $$;
revoke all on function public.support_reply(uuid, text, text) from public;
grant execute on function public.support_reply(uuid, text, text) to anon, authenticated;

-- ------------------------------------------------------------
-- 6. Backfill: every existing ticket's message becomes its first row.
--    The status trigger is disabled around the insert — otherwise every
--    backfilled ticket would flip to 'new', reopening closed ones.
--    Guarded with NOT EXISTS so a re-run adds nothing.
-- ------------------------------------------------------------
alter table public.support_messages disable trigger support_messages_set_status;
insert into public.support_messages (ticket_id, author, body, created_at)
select t.id, 'customer', t.message, t.created_at
  from public.support_tickets t
 where length(t.message) between 1 and 4000
   and not exists (select 1 from public.support_messages m where m.ticket_id = t.id);
alter table public.support_messages enable trigger support_messages_set_status;
```

Note for the executor: the `disable trigger` / `enable trigger` pair is deliberate — see the comment in section 6. Tickets whose `message` exceeds 4000 characters are skipped by the backfill (the table check would reject them); none exist today.

- [ ] **Step 2: Lint the SQL by reading it once top to bottom**

Check: every `create policy` is preceded by `drop policy if exists`; every function is `create or replace`; the trigger has `drop trigger if exists`; the two `grant execute` lines name the exact signatures; section 6 disables and re-enables the trigger around the insert.

- [ ] **Step 3: Commit (palma_app only, this file only)**

```bash
cd C:/Users/tilly/palma_app
git add supabase/migrations/045_support_thread.sql
git commit -m "feat(db): support threads — messages table, derived status, guest RPCs, backfill (045)"
git status --short   # must show only the pre-existing untracked design/ and supabase/.temp/ entries
```

- [ ] **Step 4: Owner step — apply in Supabase**

Ask the owner to paste `045_support_thread.sql` into Supabase → project `jqykkyhoxpykhixwgwyw` → SQL Editor → Run. The editor will warn about "destructive operations" because of `drop policy if exists` / `drop constraint if exists` / `drop trigger if exists` — all three drop only objects this script immediately recreates.

- [ ] **Step 5: Verify (owner runs these in the SQL Editor; paste results back)**

```sql
select count(*) as tickets from public.support_tickets;
select count(*) as messages, count(*) filter (where author = 'customer') as customer_rows from public.support_messages;
-- expected: messages = tickets, customer_rows = tickets (one backfilled row per ticket)
select id, status from public.support_tickets order by created_at desc limit 5;
-- expected: statuses unchanged by the backfill
select policyname from pg_policies where tablename = 'support_messages' order by 1;
-- expected: michelle_read (if the role exists), support_messages_admin_all, support_messages_customer_insert, support_messages_customer_select
select proname from pg_proc where proname in ('support_thread', 'support_reply', 'support_messages_set_status') order by 1;
-- expected: all three
```

Then re-run the whole migration once more: it must complete without error and the counts above must be unchanged.

---

### Task 2: Pure thread logic — `threads.ts`

**Files:**
- Create: `C:/Users/tilly/dyk-admin/src/pages/support/threads.ts`
- Test: `C:/Users/tilly/dyk-admin/src/pages/support/threads.test.ts`

**Interfaces:**
- Produces:
  ```ts
  export type Author = 'customer' | 'staff' | 'michelle'
  export type TicketStatus = 'new' | 'answered' | 'closed'
  export interface SupportMessage { id: string; ticket_id: string; author: Author; author_user_id: string | null; body: string; created_at: string }
  export type AuthorLabel = 'Customer' | 'You' | 'Staff' | 'Michelle'
  export const REPLY_MAX_CHARS = 4000
  export function groupByTicket(messages: SupportMessage[]): Map<string, SupportMessage[]>   // each list sorted by created_at ascending
  export function authorLabel(m: Pick<SupportMessage, 'author' | 'author_user_id'>, currentUserId: string | null): AuthorLabel
  export function statusLabel(s: TicketStatus): 'New' | 'Answered' | 'Closed'
  export function replyProblem(body: string): string | null   // null = ok to send
  ```

- [ ] **Step 1: Write the failing test**

```ts
// src/pages/support/threads.test.ts
import { describe, expect, it } from 'vitest'
import { authorLabel, groupByTicket, replyProblem, REPLY_MAX_CHARS, statusLabel, type SupportMessage } from './threads'

const msg = (over: Partial<SupportMessage>): SupportMessage => ({
  id: 'm', ticket_id: 't1', author: 'customer', author_user_id: null, body: 'x', created_at: '2026-09-23T22:00:00Z', ...over,
})

describe('groupByTicket', () => {
  it('groups by ticket and sorts each thread oldest first', () => {
    const g = groupByTicket([
      msg({ id: 'b', ticket_id: 't1', created_at: '2026-09-24T09:00:00Z' }),
      msg({ id: 'c', ticket_id: 't2', created_at: '2026-09-24T08:00:00Z' }),
      msg({ id: 'a', ticket_id: 't1', created_at: '2026-09-23T22:00:00Z' }),
    ])
    expect([...g.keys()]).toEqual(['t1', 't2'])
    expect(g.get('t1')!.map((m) => m.id)).toEqual(['a', 'b'])
    expect(g.get('t2')!.map((m) => m.id)).toEqual(['c'])
  })
  it('returns an empty map for no messages', () => {
    expect(groupByTicket([]).size).toBe(0)
  })
})

describe('authorLabel', () => {
  it('labels the four cases', () => {
    expect(authorLabel({ author: 'customer', author_user_id: null }, 'u1')).toBe('Customer')
    expect(authorLabel({ author: 'staff', author_user_id: 'u1' }, 'u1')).toBe('You')
    expect(authorLabel({ author: 'staff', author_user_id: 'u2' }, 'u1')).toBe('Staff')
    expect(authorLabel({ author: 'staff', author_user_id: 'u1' }, null)).toBe('Staff')
    expect(authorLabel({ author: 'michelle', author_user_id: null }, 'u1')).toBe('Michelle')
  })
})

describe('statusLabel', () => {
  it('capitalises', () => {
    expect(statusLabel('new')).toBe('New')
    expect(statusLabel('answered')).toBe('Answered')
    expect(statusLabel('closed')).toBe('Closed')
  })
})

describe('replyProblem', () => {
  it('refuses empty and whitespace, accepts text, caps at 4000 after trim', () => {
    expect(replyProblem('')).toBe('Write a reply first')
    expect(replyProblem('   \n ')).toBe('Write a reply first')
    expect(replyProblem('We moved it.')).toBeNull()
    expect(replyProblem(' ' + 'a'.repeat(REPLY_MAX_CHARS) + ' ')).toBeNull()
    expect(replyProblem('a'.repeat(REPLY_MAX_CHARS + 1))).toBe('Too long — 1 character over the 4 000 limit')
    expect(replyProblem('a'.repeat(REPLY_MAX_CHARS + 25))).toBe('Too long — 25 characters over the 4 000 limit')
  })
})
```

- [ ] **Step 2: Run to verify it fails**

```bash
cd C:/Users/tilly/dyk-admin
npx vitest run src/pages/support/threads.test.ts
```
Expected: FAIL — cannot resolve `./threads`.

- [ ] **Step 3: Implement**

```ts
// src/pages/support/threads.ts
// Pure helpers for the support inbox. No React, no Supabase — testable as-is.

export type Author = 'customer' | 'staff' | 'michelle'
export type TicketStatus = 'new' | 'answered' | 'closed'

export interface SupportMessage {
  id: string
  ticket_id: string
  author: Author
  author_user_id: string | null
  body: string
  created_at: string
}

export type AuthorLabel = 'Customer' | 'You' | 'Staff' | 'Michelle'

/** Matches the DB check on support_messages.body and the guest RPC. */
export const REPLY_MAX_CHARS = 4000

/** Messages per ticket, each thread oldest first. Insertion order of tickets follows first appearance. */
export function groupByTicket(messages: SupportMessage[]): Map<string, SupportMessage[]> {
  const out = new Map<string, SupportMessage[]>()
  for (const m of messages) {
    const list = out.get(m.ticket_id)
    if (list) list.push(m)
    else out.set(m.ticket_id, [m])
  }
  for (const list of out.values()) list.sort((a, b) => a.created_at.localeCompare(b.created_at))
  return out
}

/** The panel cannot read other admins' emails, so staff is "You" or "Staff". */
export function authorLabel(
  m: Pick<SupportMessage, 'author' | 'author_user_id'>,
  currentUserId: string | null,
): AuthorLabel {
  if (m.author === 'customer') return 'Customer'
  if (m.author === 'michelle') return 'Michelle'
  return currentUserId !== null && m.author_user_id === currentUserId ? 'You' : 'Staff'
}

export function statusLabel(s: TicketStatus): 'New' | 'Answered' | 'Closed' {
  return s === 'new' ? 'New' : s === 'answered' ? 'Answered' : 'Closed'
}

/** null when the body may be sent; otherwise the reason, ready to show. */
export function replyProblem(body: string): string | null {
  const n = body.trim().length
  if (n === 0) return 'Write a reply first'
  if (n > REPLY_MAX_CHARS) {
    const over = n - REPLY_MAX_CHARS
    return `Too long — ${over.toLocaleString('sv-SE')} character${over === 1 ? '' : 's'} over the ${REPLY_MAX_CHARS.toLocaleString('sv-SE')} limit`
  }
  return null
}
```

- [ ] **Step 4: Run to verify it passes**

```bash
npx vitest run src/pages/support/threads.test.ts
```
Expected: 5 tests pass. (`toLocaleString('sv-SE')` renders 4000 as `4 000` with a non-breaking space — the test string uses a regular space; if the assertion fails only on that character, normalise in `replyProblem` with `.replace(/\u00a0/g, ' ')` so the copy is stable across runtimes.)

- [ ] **Step 5: Commit**

```bash
git add src/pages/support/threads.ts src/pages/support/threads.test.ts
git commit -m "feat(support): pure thread helpers — grouping, author labels, reply validation"
```

---

### Task 3: `SupportThread` component with a render test

**Files:**
- Modify: `C:/Users/tilly/dyk-admin/package.json` (devDependencies)
- Create: `C:/Users/tilly/dyk-admin/src/pages/support/SupportThread.tsx`
- Test: `C:/Users/tilly/dyk-admin/src/pages/support/SupportThread.test.tsx`

**Interfaces:**
- Consumes: `authorLabel`, `replyProblem`, `REPLY_MAX_CHARS`, `SupportMessage` (Task 2); `timeAgo(iso)` from `src/useUnsavedGuard.ts`.
- Produces:
  ```ts
  export interface InsertMessageInput { ticket_id: string; author: 'staff'; author_user_id: string; body: string }
  export default function SupportThread(props: {
    ticketId: string
    messages: SupportMessage[]
    currentUserId: string | null
    insertMessage: (input: InsertMessageInput) => Promise<SupportMessage>
    onSent: (m: SupportMessage) => void
  }): JSX.Element
  ```

- [ ] **Step 1: Add the test tooling**

```bash
cd C:/Users/tilly/dyk-admin
npm install --save-dev jsdom@^26.1.0 @testing-library/react@^16.3.0
```
If either version does not resolve, use the latest of the same major. Both are dev-only; nothing ships to the browser.

- [ ] **Step 2: Write the failing render test**

```tsx
// @vitest-environment jsdom
// src/pages/support/SupportThread.test.tsx
import { describe, expect, it, vi } from 'vitest'
import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import SupportThread from './SupportThread'
import type { SupportMessage } from './threads'

const thread: SupportMessage[] = [
  { id: '1', ticket_id: 't', author: 'customer', author_user_id: null, body: 'the hotspot el corte ingles is wrongly located', created_at: '2026-09-23T22:00:00Z' },
  { id: '2', ticket_id: 't', author: 'michelle', author_user_id: null, body: 'Thanks — we are checking the pin.', created_at: '2026-09-24T08:00:00Z' },
  { id: '3', ticket_id: 't', author: 'staff', author_user_id: 'u1', body: 'Moved it 40 m north.', created_at: '2026-09-24T09:00:00Z' },
]

function setup(insert = vi.fn(), onSent = vi.fn()) {
  render(<SupportThread ticketId="t" messages={thread} currentUserId="u1" insertMessage={insert} onSent={onSent} />)
  return { insert, onSent }
}

describe('SupportThread', () => {
  it('renders the thread in order with author labels and the Michelle badge', () => {
    setup()
    const items = screen.getAllByRole('listitem')
    expect(items).toHaveLength(3)
    expect(items[0].textContent).toContain('Customer')
    expect(items[0].textContent).toContain('wrongly located')
    expect(items[1].textContent).toContain('Michelle')
    expect(items[2].textContent).toContain('You')
    expect(screen.getAllByTestId('michelle-badge')).toHaveLength(1)
  })

  it('refuses an empty reply', () => {
    const { insert } = setup()
    const button = screen.getByRole('button', { name: /send reply/i }) as HTMLButtonElement
    expect(button.disabled).toBe(true)
    fireEvent.click(button)
    expect(insert).not.toHaveBeenCalled()
  })

  it('sends a staff message and reports it back', async () => {
    const returned: SupportMessage = { id: '4', ticket_id: 't', author: 'staff', author_user_id: 'u1', body: 'We moved it.', created_at: '2026-09-24T10:00:00Z' }
    const insert = vi.fn().mockResolvedValue(returned)
    const { onSent } = setup(insert)
    fireEvent.change(screen.getByLabelText('Reply'), { target: { value: '  We moved it.  ' } })
    fireEvent.click(screen.getByRole('button', { name: /send reply/i }))
    await waitFor(() => expect(insert).toHaveBeenCalledWith({ ticket_id: 't', author: 'staff', author_user_id: 'u1', body: 'We moved it.' }))
    await waitFor(() => expect(onSent).toHaveBeenCalledWith(returned))
    expect((screen.getByLabelText('Reply') as HTMLTextAreaElement).value).toBe('')
  })

  it('keeps the text and shows the error when the insert fails', async () => {
    const insert = vi.fn().mockRejectedValue(new Error('new row violates row-level security policy'))
    const { onSent } = setup(insert)
    fireEvent.change(screen.getByLabelText('Reply'), { target: { value: 'Hello' } })
    fireEvent.click(screen.getByRole('button', { name: /send reply/i }))
    await waitFor(() => expect(screen.getByRole('alert').textContent).toContain('row-level security'))
    expect((screen.getByLabelText('Reply') as HTMLTextAreaElement).value).toBe('Hello')
    expect(onSent).not.toHaveBeenCalled()
  })
})
```

- [ ] **Step 3: Run to verify it fails**

```bash
npx vitest run src/pages/support/SupportThread.test.tsx
```
Expected: FAIL — cannot resolve `./SupportThread`.

- [ ] **Step 4: Implement**

```tsx
// src/pages/support/SupportThread.tsx
import { useState } from 'react'
import { Send } from 'lucide-react'
import { timeAgo } from '../../useUnsavedGuard'
import { authorLabel, replyProblem, REPLY_MAX_CHARS, type SupportMessage } from './threads'

export interface InsertMessageInput {
  ticket_id: string
  author: 'staff'
  author_user_id: string
  body: string
}

/** One ticket's conversation plus the staff reply box. The insert is injected
 *  so the component can be rendered in tests without a Supabase client. */
export default function SupportThread({ ticketId, messages, currentUserId, insertMessage, onSent }: {
  ticketId: string
  messages: SupportMessage[]
  currentUserId: string | null
  insertMessage: (input: InsertMessageInput) => Promise<SupportMessage>
  onSent: (m: SupportMessage) => void
}) {
  const [body, setBody] = useState('')
  const [sending, setSending] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const problem = replyProblem(body)
  const canSend = !sending && problem === null && currentUserId !== null

  const send = async () => {
    if (!canSend || currentUserId === null) return
    setSending(true)
    setError(null)
    try {
      const m = await insertMessage({ ticket_id: ticketId, author: 'staff', author_user_id: currentUserId, body: body.trim() })
      setBody('')
      onSent(m)
    } catch (e) {
      setError((e as Error).message)
    } finally {
      setSending(false)
    }
  }

  return (
    <div>
      <ul style={{ listStyle: 'none', padding: 0, margin: '0 0 0.7rem' }}>
        {messages.map((m) => (
          <li key={m.id} style={{ marginBottom: '0.55rem' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: '0.75rem' }}>
              <strong>{authorLabel(m, currentUserId)}</strong>
              {m.author === 'michelle' && (
                <span className="badge" data-testid="michelle-badge" style={{ background: '#7dd3fc', color: 'var(--black)', fontWeight: 900 }}>AI</span>
              )}
              <span className="muted" title={m.created_at}>{timeAgo(m.created_at)}</span>
            </div>
            <p style={{ margin: '0.15rem 0 0', whiteSpace: 'pre-wrap', lineHeight: 1.5 }}>{m.body}</p>
          </li>
        ))}
      </ul>

      <textarea
        aria-label="Reply"
        value={body}
        onChange={(e) => setBody(e.target.value)}
        rows={3}
        disabled={sending}
        placeholder="Reply to the customer…"
        style={{ width: '100%', boxSizing: 'border-box' }}
      />
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: '0.25rem', fontSize: '0.78rem' }}>
        <span className="muted" style={{ fontVariantNumeric: 'tabular-nums' }}>
          {body.trim().length.toLocaleString('sv-SE')} / {REPLY_MAX_CHARS.toLocaleString('sv-SE')}
        </span>
        <button className="btn small" disabled={!canSend} onClick={send}>
          <Send size={15} /> {sending ? 'Sending…' : 'Send reply'}
        </button>
      </div>
      {error && (
        <p role="alert" style={{ color: '#e5484d', margin: '0.3rem 0 0', fontSize: '0.8rem' }}>{error}</p>
      )}
    </div>
  )
}
```

- [ ] **Step 5: Run to verify it passes**

```bash
npx vitest run src/pages/support/SupportThread.test.tsx
```
Expected: 4 tests pass. If React warns about `act(...)`, wrap nothing — `@testing-library/react` 16 handles React 19's act environment; a warning in the output is a finding, not something to silence.

- [ ] **Step 6: Typecheck**

```bash
npx tsc --noEmit
```
Expected: clean. (`noUnusedLocals` is on — every import in the component and the test must be used.)

- [ ] **Step 7: Commit**

```bash
git add package.json package-lock.json src/pages/support/SupportThread.tsx src/pages/support/SupportThread.test.tsx
git commit -m "feat(support): SupportThread — thread view with staff reply box (jsdom render test)"
```

---

### Task 4: `SupportPage` loads threads and composes the inbox

**Files:**
- Modify: `C:/Users/tilly/dyk-admin/src/pages/SupportPage.tsx` (whole file replaced)

**Interfaces:**
- Consumes: `SupportThread`, `InsertMessageInput` (Task 3); `groupByTicket`, `statusLabel`, `SupportMessage`, `TicketStatus` (Task 2); `supabase` from `src/supabase.ts`; `timeAgo`.
- Produces: the same default export and `onCountChange` prop `App.tsx` already uses (`App.tsx:200`) — nothing else in the app changes.

- [ ] **Step 1: Replace the file**

```tsx
// src/pages/SupportPage.tsx
import { useEffect, useState } from 'react'
import { LifeBuoy, Trash2, CheckCircle2, RotateCcw, Mail } from 'lucide-react'
import { supabase } from '../supabase'
import { timeAgo } from '../useUnsavedGuard'
import SupportThread, { type InsertMessageInput } from './support/SupportThread'
import { groupByTicket, statusLabel, type SupportMessage, type TicketStatus } from './support/threads'

interface SupportTicket {
  id: string
  user_id: string | null
  install_id: string | null
  email: string
  message: string
  status: TicketStatus
  created_at: string
  updated_at: string
}

type Filter = TicketStatus | 'all'
const FILTERS: Filter[] = ['new', 'answered', 'closed', 'all']

/** Inbox for Help & Support conversations from the app. */
export default function SupportPage({ onCountChange }: { onCountChange?: (n: number) => void }) {
  const [tickets, setTickets] = useState<SupportTicket[]>([])
  const [threads, setThreads] = useState<Map<string, SupportMessage[]>>(new Map())
  const [threadError, setThreadError] = useState<string | null>(null)
  const [currentUserId, setCurrentUserId] = useState<string | null>(null)
  const [filter, setFilter] = useState<Filter>('new')

  const report = (list: SupportTicket[]) =>
    onCountChange?.(list.filter((t) => t.status === 'new').length)

  const load = async () => {
    const { data } = await supabase
      .from('support_tickets')
      .select('*')
      .order('created_at', { ascending: false })
    const list = (data ?? []) as SupportTicket[]
    setTickets(list)
    report(list)
    if (list.length === 0) {
      setThreads(new Map())
      return
    }
    const { data: msgs, error } = await supabase
      .from('support_messages')
      .select('*')
      .in('ticket_id', list.map((t) => t.id))
      .order('created_at', { ascending: true })
    if (error) {
      setThreadError(error.message)
      return
    }
    setThreadError(null)
    setThreads(groupByTicket((msgs ?? []) as SupportMessage[]))
  }

  useEffect(() => {
    load()
    supabase.auth.getUser().then(({ data }) => setCurrentUserId(data.user?.id ?? null))
  }, [])

  const setStatus = async (t: SupportTicket, status: TicketStatus) => {
    const next = tickets.map((x) => (x.id === t.id ? { ...x, status } : x))
    setTickets(next)
    report(next)
    await supabase.from('support_tickets').update({ status }).eq('id', t.id)
  }

  const remove = async (t: SupportTicket) => {
    if (!confirm('Delete this ticket and its whole conversation permanently?')) return
    const next = tickets.filter((x) => x.id !== t.id)
    setTickets(next)
    report(next)
    await supabase.from('support_tickets').delete().eq('id', t.id)
  }

  const insertMessage = async (input: InsertMessageInput): Promise<SupportMessage> => {
    const { data, error } = await supabase.from('support_messages').insert(input).select('*').single()
    if (error) throw new Error(error.message)
    return data as SupportMessage
  }

  // The DB trigger already set the ticket to 'answered'; mirror it locally.
  const onSent = (m: SupportMessage) => {
    setThreads((prev) => {
      const next = new Map(prev)
      next.set(m.ticket_id, [...(next.get(m.ticket_id) ?? []), m])
      return next
    })
    const next = tickets.map((x) => (x.id === m.ticket_id ? { ...x, status: 'answered' as const } : x))
    setTickets(next)
    report(next)
  }

  const count = (s: TicketStatus) => tickets.filter((t) => t.status === s).length
  const shown = tickets.filter((t) => (filter === 'all' ? true : t.status === filter))

  return (
    <>
      <div className="page-head">
        <div className="ph-title">
          <span className="ph-badge"><LifeBuoy size={24} /></span>
          <div>
            <h2>Support</h2>
            <p className="sub" style={{ marginBottom: 0 }}>
              Conversations from the app's Help &amp; Support. Reply here; the customer sees it in the app.
            </p>
          </div>
        </div>
      </div>

      <div className="filter-bar">
        <div className="pill-tabs">
          {FILTERS.map((f) => (
            <button key={f} className={filter === f ? 'active' : ''} onClick={() => setFilter(f)}>
              {f === 'all' ? 'All' : `${statusLabel(f)} (${count(f)})`}
            </button>
          ))}
        </div>
      </div>

      {shown.length === 0 && (
        <div className="card" style={{ textAlign: 'center', padding: '2rem' }}>
          <p className="muted" style={{ margin: 0 }}>
            {filter === 'new' ? 'Inbox zero — no open tickets! 🎉' : 'Nothing here.'}
          </p>
        </div>
      )}

      {shown.map((t) => (
        <div
          key={t.id}
          className="card"
          style={{
            padding: '1rem 1.2rem',
            marginBottom: '0.7rem',
            borderLeft: t.status === 'new' ? '4px solid var(--yellow)' : '4px solid transparent',
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: '0.6rem', flexWrap: 'wrap' }}>
            {t.status === 'new' && (
              <span className="badge" style={{ background: 'var(--yellow)', color: 'var(--black)', fontWeight: 900 }}>NEW</span>
            )}
            <a href={`mailto:${t.email}`} style={{ fontWeight: 800, color: 'var(--yellow)', textDecoration: 'none', display: 'inline-flex', alignItems: 'center', gap: 6 }}>
              <Mail size={14} /> {t.email}
            </a>
            {t.user_id && <span className="badge" style={{ background: 'var(--border)', color: '#ccc' }}>ACCOUNT</span>}
            {!t.user_id && t.install_id && <span className="badge" style={{ background: 'var(--border)', color: '#ccc' }}>DEVICE</span>}
            <span className="muted" style={{ marginLeft: 'auto', fontSize: '0.75rem' }} title={t.created_at}>
              {timeAgo(t.created_at)}
            </span>
          </div>

          {threadError ? (
            <>
              <p style={{ margin: '0 0 0.4rem', whiteSpace: 'pre-wrap', lineHeight: 1.5 }}>{t.message}</p>
              <p className="muted" style={{ margin: '0 0 0.7rem', fontSize: '0.8rem' }}>Could not load the conversation: {threadError}</p>
            </>
          ) : (
            <SupportThread
              ticketId={t.id}
              messages={threads.get(t.id) ?? []}
              currentUserId={currentUserId}
              insertMessage={insertMessage}
              onSent={onSent}
            />
          )}

          <div style={{ display: 'flex', gap: '0.5rem', marginTop: '0.7rem' }}>
            {t.status === 'closed' ? (
              <button className="btn small secondary" onClick={() => setStatus(t, 'new')}>
                <RotateCcw size={15} /> Reopen
              </button>
            ) : (
              <button className="btn small" onClick={() => setStatus(t, 'closed')}>
                <CheckCircle2 size={15} /> Close
              </button>
            )}
            <button className="btn small danger" onClick={() => remove(t)}>
              <Trash2 size={15} /> Delete
            </button>
          </div>
        </div>
      ))}
    </>
  )
}
```

- [ ] **Step 2: Typecheck, test, build**

```bash
cd C:/Users/tilly/dyk-admin
npx tsc --noEmit
npx vitest run
npm run build
```
Expected: no type errors; all tests pass (the pre-existing `limits.test.ts` plus 5 + 4 new); build succeeds.

- [ ] **Step 3: Commit**

```bash
git add src/pages/SupportPage.tsx
git commit -m "feat(support): inbox shows conversations, staff reply, New/Answered/Closed filters"
```

---

### Task 5: Live verification against the real ticket

**Files:** none (manual, after Task 1 Step 4 has been done by the owner).

- [ ] **Step 1: Run the panel locally**

```bash
cd C:/Users/tilly/dyk-admin
npm run dev
```
Sign in as an admin. Open **Support**. Expected: the real ticket (*"the hotspot el corte ingles is wrongly located"*) shows as a one-message thread labelled **Customer** under the **New (1)** tab, with the reply box below.

- [ ] **Step 2: Reply**

Type a real reply (the owner decides the text — it is stored, and the customer will see it once C ships) and press **Send reply**. Expected: the message appears in the thread labelled **You**; the ticket moves from **New (1)** to **Answered (1)**; the sidebar count drops to 0.

- [ ] **Step 3: Independent witness — Michelle reads the thread**

From `C:/Users/tilly/michelle`, with the `michelle_ro` role (SELECT only):

```bash
cd C:/Users/tilly/michelle
node -e "require('dotenv').config();const {Client}=require('pg');(async()=>{const c=new Client({connectionString:process.env.MICHELLE_PASSIM_DB_URL,ssl:{rejectUnauthorized:false}});await c.connect();const r=await c.query(\"select t.status, m.author, left(m.body,60) as body, m.created_at from support_tickets t join support_messages m on m.ticket_id=t.id order by m.created_at\");console.table(r.rows);await c.end()})()"
```
Expected: two rows — `customer` then `staff` — and `status = answered` on both. If `michelle_read` was not created (role missing when the migration ran), this query returns zero rows: re-run the migration now that the role exists.

- [ ] **Step 4: Record the outcome**

Append to the spec's §8 (Known gaps) a dated line: "Verified 2026-09-XX: real ticket answered from admin; status derived; Michelle reads the thread." Commit that one-line change in `palma_app`:

```bash
cd C:/Users/tilly/palma_app
git add docs/superpowers/specs/2026-09-24-support-thread-design.md
git commit -m "docs: support thread verified live"
```

---

## Self-review against the spec

**Spec coverage:**
- §3.1 table and columns → Task 1 §2 (exact names/types/checks, index).
- §3.2 `install_id`, widened status, `message` untouched → Task 1 §1; `SupportPage` shows a DEVICE badge when only `install_id` is set.
- §3.3 derived status trigger, security definer, explicit close/reopen kept → Task 1 §3; `SupportPage` `setStatus`.
- §3.4 RLS: admin all; customer select/insert with `author='customer'` and null `author_user_id`; guest via RPCs; `michelle_read` conditional → Task 1 §4–5.
- §3.4 guest RPCs expose `from_customer`, not the author word → Task 1 §5 (`'from_customer', m.author = 'customer'`); Global Constraints.
- §3.5 backfill idempotent and not status-changing → Task 1 §6 (trigger disabled around the insert; `not exists` guard).
- §4.1 thread, labels (Customer/You/Staff/Michelle + badge), reply box with counter and 4000 cap, filters New/Answered/Closed/All, Close/Reopen/Delete, `mailto:` kept → Tasks 2–4.
- §4.2 structure (`SupportPage`, `support/SupportThread.tsx`, `support/threads.ts`) → Tasks 2–4; no new runtime deps (only dev deps in Task 3).
- §5 failures: insert fails → text kept + inline error (Task 3 test 4); messages query fails → card falls back to `ticket.message` + inline line (Task 4); migration re-run → Task 1 Step 5; wrong `install_id` → `not found` (Task 1 §5).
- §6 testing: migration verified by owner + Michelle witness (Task 1 Step 5, Task 5 Step 3); `threads.ts` unit tests (Task 2); `SupportThread` jsdom render test (Task 3); manual end-to-end (Task 5).
- §7/§8 out of scope and known gaps: nothing in the plan builds delivery, Michelle's writes, or the app inbox.

**Placeholder scan:** none. The only "owner decides" item is the reply text in Task 5 Step 2 — a genuine human input, not a plan gap.

**Type consistency:** `SupportMessage` (Task 2) is the type returned by `insertMessage` (Task 3 signature, Task 4 implementation), stored in `threads` (Task 4), and rendered by `SupportThread` (Task 3). `InsertMessageInput.author` is the literal `'staff'` in Task 3 and Task 4. `TicketStatus` is shared by `SupportTicket` and `Filter` in Task 4 and by `statusLabel` in Task 2. `authorLabel(m, currentUserId)` — same two-argument shape in Task 2 and Task 3.
