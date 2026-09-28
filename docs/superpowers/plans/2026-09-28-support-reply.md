# Michelle Answers Support Tickets (Michelle v2 — sub-project B) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Michelle can find unanswered Passim support tickets, propose a reply out loud, and — only after the owner's explicit spoken approval — send it, using a new database role that can do nothing but that one insert.

**Architecture:** A new Postgres role `michelle_rw`, separate from the existing read-only `michelle_ro`, can INSERT into `support_messages` only as `author = 'michelle'`. In the `michelle` server, a new `WriteDb` connection (own file, own pool, never touches the read-only `Db`) exposes exactly one method: `insertSupportReply`. A `PendingReplyStore` holds at most one staged draft. Three new tools — `support_pending` (fast tier, read-only), `propose_support_reply` and `send_support_reply` (broad tier only) — are added alongside the existing Passim/PalmaCrew tools; `send_support_reply`'s input schema has no body field, so the model has no way to submit new text at send time — it can only confirm which already-staged draft to fire.

**Tech Stack:** Node 20 / TypeScript, `pg`, Vitest. Same stack as the rest of `michelle`. Postgres/Supabase (project `jqykkyhoxpykhixwgwyw`) for the migration.

**Spec:** `C:/Users/tilly/palma_app/docs/superpowers/specs/2026-09-28-support-reply-design.md` — read it first.

## Global Constraints

- **`send_support_reply`'s input schema never has a `body` field.** This is the load-bearing safety property of the whole feature (spec §3) — no task may add one, even to "make testing easier."
- **The write role can do exactly one thing:** INSERT into `support_messages` with `author = 'michelle' and author_user_id is null`. No SELECT, UPDATE, DELETE grant, no grant on any other table.
- **`db.ts` is never modified.** It is the file the entire read-only guarantee rests on. The write path lives entirely in a new, separate file (`writedb.ts`) that only imports the `PoolLike` *type* from `db.ts`.
- **One pending draft at a time.** `PendingReplyStore` holds a single nullable slot, never a map or list — `propose` replaces whatever was there.
- **Reply body 1–4000 characters**, validated in `propose_support_reply` before anything is staged (mirrors the `support_messages` DB check).
- **Repo boundaries:** the migration is the only change in `palma_app` (repo `C:/Users/tilly/palma_app`, branch `main`); every other task is in `michelle` (repo `C:/Users/tilly/michelle`, branch `main`). Follow each repo's own multi-session rules (`palma_app/CLAUDE.md`) — `git log --oneline -10` and `git status` before starting work there.
- **Migration 048 is applied by the owner** in the Supabase SQL Editor, never automatically. Code that depends on it (`send_support_reply`, the write-role integration test) must degrade gracefully (`WriteDbUnavailable`) until then.
- **Test gate:** `pnpm test` (unit) must stay green after every task; `pnpm typecheck` must stay clean. `pnpm test:int` (which now includes the new write-role integration test) is owner-run once the migration and `.env` are in place — it is expected to skip, not fail, before that.

---

## File Structure

```
palma_app/supabase/migrations/048_michelle_support_writer.sql   the michelle_rw role + policy

michelle/src/server/tools/pending-reply-store.ts    PendingReplyStore: propose/get/clear, one slot
michelle/src/server/writedb.ts                      WriteDb, WriteDbUnavailable, createWriteDb — separate from db.ts
michelle/src/server/config.ts                        MODIFIED: passimWriteDbUrl
michelle/src/server/tools/registry.ts                MODIFIED: ToolContext gains writeDb, pendingReply
michelle/src/server/tools/format.ts                  MODIFIED: truncate()
michelle/src/server/tools/support.ts                 supportPending, proposeSupportReply, sendSupportReply
michelle/src/server/index.ts                         MODIFIED: wire writeDb/pendingReply/new tools in
michelle/src/server/brain.ts                          MODIFIED: SYSTEM prompt rules for the new tools
michelle/.env.example                                 MODIFIED: MICHELLE_PASSIM_WRITE_DB_URL

michelle/test/unit/tools/pending-reply-store.test.ts
michelle/test/unit/writedb.test.ts
michelle/test/unit/config.test.ts                     MODIFIED
michelle/test/unit/tools/format.test.ts                MODIFIED
michelle/test/unit/tools/support.test.ts
michelle/test/integration/writedb.int.test.ts
```

---

### Task 1: Migration `048_michelle_support_writer.sql`

**Files:**
- Create: `palma_app/supabase/migrations/048_michelle_support_writer.sql`

**Interfaces:**
- Produces: Postgres role `michelle_rw` and policy `michelle_rw_insert` on `public.support_messages` — INSERT only, `with check (author = 'michelle' and author_user_id is null)`.

- [ ] **Step 1: Write the migration**

```sql
-- 048_michelle_support_writer.sql — Michelle's write role: exactly one thing.
-- Idempotent: safe to re-run. Run in Supabase → SQL Editor as the default (postgres) user.
-- Replace REPLACE_ME with a long random password before running.
--
-- What this grants: INSERT on support_messages, and only when the row is
-- shaped author='michelle', author_user_id is null. No SELECT, no UPDATE,
-- no DELETE, no other table, no other schema. This role cannot even read
-- back the row it just inserted — every read Michelle does still goes
-- through the existing michelle_ro role (db/michelle_role.sql).

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'michelle_rw') then
    create role michelle_rw
      login password 'REPLACE_ME'
      nosuperuser nocreatedb nocreaterole noinherit;
  end if;
end $$;

alter role michelle_rw set statement_timeout = '8s';

grant usage on schema public to michelle_rw;
grant insert on public.support_messages to michelle_rw;

drop policy if exists michelle_rw_insert on public.support_messages;
create policy michelle_rw_insert on public.support_messages
  for insert to michelle_rw
  with check (author = 'michelle' and author_user_id is null);

-- Verify (run separately, should return one row with rolsuper = false):
-- select rolname, rolsuper, rolcreaterole, rolcreatedb from pg_roles where rolname = 'michelle_rw';
```

- [ ] **Step 2: Read it once top to bottom**

Check: the role creation is guarded by `if not exists` (idempotent, matches `db/michelle_role.sql`'s pattern); `grant insert` names `support_messages` only; the policy's `with check` matches spec §5 exactly (`author = 'michelle' and author_user_id is null`); nothing grants SELECT, UPDATE, or DELETE anywhere in the file.

- [ ] **Step 3: Commit (this file only)**

```bash
cd C:/Users/tilly/palma_app
git add supabase/migrations/048_michelle_support_writer.sql
git commit -m "feat(db): michelle_rw — insert-only role for Michelle's support replies (048)"
git status --short
```

- [ ] **Step 4: Owner step — apply and verify**

Owner replaces `REPLACE_ME` with a real password, pastes the file into Supabase → SQL Editor → Run, saves that password into `michelle/.env` as `MICHELLE_PASSIM_WRITE_DB_URL` (session-pooler connection string for `michelle_rw`, same host/port shape as the existing `MICHELLE_PASSIM_DB_URL`). Then, in the editor:

```sql
select rolname, rolsuper, rolcreaterole, rolcreatedb from pg_roles where rolname = 'michelle_rw';
-- expect one row, rolsuper = false
select count(*) from information_schema.role_table_grants
 where grantee = 'michelle_rw' and table_name = 'support_messages';
-- expect 1 (insert only)
```

---

### Task 2: `PendingReplyStore`

**Files:**
- Create: `michelle/src/server/tools/pending-reply-store.ts`
- Test: `michelle/test/unit/tools/pending-reply-store.test.ts`

**Interfaces:**
- Produces: `interface PendingReply { ticketId: string; body: string; proposedAt: string }`; `class PendingReplyStore { propose(ticketId: string, body: string, proposedAt?: Date): void; get(): PendingReply | null; clear(): void }`.

- [ ] **Step 1: Write the failing tests**

```typescript
import { describe, it, expect } from 'vitest';
import { PendingReplyStore } from '../../../src/server/tools/pending-reply-store';

describe('PendingReplyStore', () => {
  it('starts empty', () => {
    expect(new PendingReplyStore().get()).toBeNull();
  });

  it('holds what was proposed', () => {
    const store = new PendingReplyStore();
    store.propose('t1', 'We are on it.', new Date('2026-09-28T10:00:00.000Z'));
    expect(store.get()).toEqual({ ticketId: 't1', body: 'We are on it.', proposedAt: '2026-09-28T10:00:00.000Z' });
  });

  it('replaces an earlier draft instead of holding two', () => {
    const store = new PendingReplyStore();
    store.propose('t1', 'first draft');
    store.propose('t2', 'second draft');
    expect(store.get()).toMatchObject({ ticketId: 't2', body: 'second draft' });
  });

  it('clear empties the slot', () => {
    const store = new PendingReplyStore();
    store.propose('t1', 'x');
    store.clear();
    expect(store.get()).toBeNull();
  });

  it('defaults proposedAt to now when not given', () => {
    const store = new PendingReplyStore();
    const before = Date.now();
    store.propose('t1', 'x');
    const at = new Date(store.get()!.proposedAt).getTime();
    expect(at).toBeGreaterThanOrEqual(before);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd C:/Users/tilly/michelle && npx vitest run test/unit/tools/pending-reply-store.test.ts`
Expected: FAIL — cannot find module `../../../src/server/tools/pending-reply-store`.

- [ ] **Step 3: Write the implementation**

```typescript
export interface PendingReply {
  ticketId: string;
  body: string;
  proposedAt: string;
}

/** Holds at most one drafted-but-unsent support reply. Michelle works one ticket at a time by design. */
export class PendingReplyStore {
  private current: PendingReply | null = null;

  propose(ticketId: string, body: string, proposedAt: Date = new Date()): void {
    this.current = { ticketId, body, proposedAt: proposedAt.toISOString() };
  }

  get(): PendingReply | null {
    return this.current;
  }

  clear(): void {
    this.current = null;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npx vitest run test/unit/tools/pending-reply-store.test.ts`
Expected: PASS, all 5 tests.

- [ ] **Step 5: Commit**

```bash
cd C:/Users/tilly/michelle
git add src/server/tools/pending-reply-store.ts test/unit/tools/pending-reply-store.test.ts
git commit -m "feat: PendingReplyStore — one staged support reply at a time"
```

---

### Task 3: `WriteDb`

**Files:**
- Create: `michelle/src/server/writedb.ts`
- Test: `michelle/test/unit/writedb.test.ts`

**Interfaces:**
- Consumes: `PoolLike` (type only) from `michelle/src/server/db.ts:22-28` — `{ connect(): Promise<{ query(sql, params?): Promise<{rows, rowCount}>; release(): void }>; end(): Promise<void> }`.
- Produces: `interface WriteDb { insertSupportReply(ticketId: string, body: string): Promise<{ id: string }>; close(): Promise<void> }`; `class WriteDbUnavailable extends Error`; `function createWriteDb(url: string | undefined, deps?: { poolFactory?: (url: string) => PoolLike }): WriteDb`.

- [ ] **Step 1: Write the failing tests**

```typescript
import { describe, it, expect, vi } from 'vitest';
import { createWriteDb, WriteDbUnavailable } from '../../src/server/writedb';

function fakePool() {
  const queries: { sql: string; params?: unknown[] }[] = [];
  const client = {
    query: vi.fn(async (sql: string, params?: unknown[]) => {
      queries.push({ sql, params });
      return { rows: [{ id: 'msg-1' }], rowCount: 1 };
    }),
    release: vi.fn(),
  };
  const pool = { connect: vi.fn(async () => client), end: vi.fn(async () => {}) };
  return { pool, client, queries };
}

describe('createWriteDb', () => {
  it('inserts with a fixed author and returns the new id', async () => {
    const f = fakePool();
    const db = createWriteDb('postgres://x', { poolFactory: () => f.pool });
    const r = await db.insertSupportReply('ticket-1', 'We are on it.');
    expect(r).toEqual({ id: 'msg-1' });
    expect(f.queries).toHaveLength(1);
    expect(f.queries[0].sql).toMatch(/insert into public\.support_messages/i);
    expect(f.queries[0].sql).toMatch(/'michelle'/);
    expect(f.queries[0].params).toEqual(['ticket-1', 'We are on it.']);
    expect(f.client.release).toHaveBeenCalledOnce();
  });

  it('releases the client even if the insert throws', async () => {
    const f = fakePool();
    f.client.query.mockImplementationOnce(async () => { throw new Error('boom'); });
    const db = createWriteDb('postgres://x', { poolFactory: () => f.pool });
    await expect(db.insertSupportReply('t', 'x')).rejects.toThrow('boom');
    expect(f.client.release).toHaveBeenCalledOnce();
  });

  it('throws WriteDbUnavailable when no url is configured', async () => {
    const db = createWriteDb(undefined, { poolFactory: () => fakePool().pool });
    await expect(db.insertSupportReply('t', 'x')).rejects.toBeInstanceOf(WriteDbUnavailable);
  });

  it('creates the pool lazily, once', async () => {
    const factory = vi.fn(() => fakePool().pool);
    const db = createWriteDb('postgres://x', { poolFactory: factory });
    await db.insertSupportReply('t', 'a');
    await db.insertSupportReply('t', 'b');
    expect(factory).toHaveBeenCalledTimes(1);
  });

  it('close ends the pool if one was ever created', async () => {
    const f = fakePool();
    const db = createWriteDb('postgres://x', { poolFactory: () => f.pool });
    await db.insertSupportReply('t', 'x');
    await db.close();
    expect(f.pool.end).toHaveBeenCalledOnce();
  });

  it('close is a no-op when no pool was ever created', async () => {
    const db = createWriteDb(undefined);
    await expect(db.close()).resolves.toBeUndefined();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run test/unit/writedb.test.ts`
Expected: FAIL — cannot find module `../../src/server/writedb`.

- [ ] **Step 3: Write the implementation**

```typescript
import { Pool } from 'pg';
import type { PoolLike } from './db';

export interface WriteDb {
  insertSupportReply(ticketId: string, body: string): Promise<{ id: string }>;
  close(): Promise<void>;
}

export class WriteDbUnavailable extends Error {
  constructor(reason: string) {
    super(`support write database unavailable: ${reason}`);
    this.name = 'WriteDbUnavailable';
  }
}

// Fixed statement: this role can only ever insert one shape of row.
// See supabase/migrations/048_michelle_support_writer.sql in palma_app.
const INSERT_SQL = `insert into public.support_messages (ticket_id, author, body) values ($1, 'michelle', $2) returning id`;

const defaultWritePoolFactory = (url: string): PoolLike =>
  new Pool({
    connectionString: url,
    ssl: { rejectUnauthorized: false },
    max: 2,
    idleTimeoutMillis: 30_000,
    connectionTimeoutMillis: 5_000,
  });

export function createWriteDb(
  url: string | undefined,
  deps: { poolFactory?: (url: string) => PoolLike } = {}
): WriteDb {
  const factory = deps.poolFactory ?? defaultWritePoolFactory;
  let pool: PoolLike | undefined;

  function poolOrThrow(): PoolLike {
    if (!url) throw new WriteDbUnavailable('no connection string configured');
    if (!pool) pool = factory(url);
    return pool;
  }

  return {
    async insertSupportReply(ticketId, body) {
      const client = await poolOrThrow().connect();
      try {
        const r = await client.query(INSERT_SQL, [ticketId, body]);
        return { id: String(r.rows[0].id) };
      } finally {
        client.release();
      }
    },
    async close() {
      if (pool) await pool.end();
    },
  };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npx vitest run test/unit/writedb.test.ts`
Expected: PASS, all 6 tests.

- [ ] **Step 5: Commit**

```bash
git add src/server/writedb.ts test/unit/writedb.test.ts
git commit -m "feat: WriteDb — one hardcoded insert, its own connection, db.ts untouched"
```

---

### Task 4: `Config.passimWriteDbUrl`

**Files:**
- Modify: `michelle/src/server/config.ts`
- Modify: `michelle/test/unit/config.test.ts`
- Modify: `michelle/.env.example`

**Interfaces:**
- Produces: `Config.passimWriteDbUrl: string | undefined`, read from env var `MICHELLE_PASSIM_WRITE_DB_URL`.

- [ ] **Step 1: Add the failing test cases**

Add to `test/unit/config.test.ts`, inside the existing `describe('loadConfig', ...)` block:

```typescript
  it('leaves passimWriteDbUrl undefined when not set', () => {
    const c = loadConfig(full);
    expect(c.passimWriteDbUrl).toBeUndefined();
  });
  it('reads passimWriteDbUrl when set', () => {
    const c = loadConfig({ ...full, MICHELLE_PASSIM_WRITE_DB_URL: 'postgres://rw' });
    expect(c.passimWriteDbUrl).toBe('postgres://rw');
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run test/unit/config.test.ts`
Expected: FAIL — `c.passimWriteDbUrl` is `undefined` when expected `'postgres://rw'` (property does not exist on the object built by `loadConfig`).

- [ ] **Step 3: Implement**

In `src/server/config.ts`, add to the `Config` interface (after `dbUrls`):

```typescript
  dbUrls: Partial<Record<Project, string>>;
  /** Session-pooler URL for the michelle_rw role (insert-only on support_messages). Optional: unset until the owner runs migration 048. */
  passimWriteDbUrl?: string;
```

And in `loadConfig`'s returned object (after `dbUrls,`):

```typescript
    dbUrls,
    passimWriteDbUrl: env.MICHELLE_PASSIM_WRITE_DB_URL,
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npx vitest run test/unit/config.test.ts`
Expected: PASS, all tests (existing 3 + new 2).

- [ ] **Step 5: Update `.env.example`**

Add after the existing `MICHELLE_PASSIM_DB_URL` / `MICHELLE_PALMACREW_DB_URL` lines:

```
# Session-pooler connection string for the michelle_rw role (see
# palma_app/supabase/migrations/048_michelle_support_writer.sql). Optional —
# unset until the owner applies that migration; send_support_reply reports
# unavailable until then.
MICHELLE_PASSIM_WRITE_DB_URL=
```

- [ ] **Step 6: Commit**

```bash
git add src/server/config.ts test/unit/config.test.ts .env.example
git commit -m "feat: config — optional MICHELLE_PASSIM_WRITE_DB_URL"
```

---

### Task 5: `ToolContext` gains `writeDb` and `pendingReply`

**Files:**
- Modify: `michelle/src/server/tools/registry.ts`

**Interfaces:**
- Consumes: `WriteDb` from `../writedb` (Task 3); `PendingReplyStore` from `./pending-reply-store` (Task 2).
- Produces: `ToolContext` now requires `writeDb: WriteDb` and `pendingReply: PendingReplyStore` alongside the existing `db`, `repos`, `now?`.

**Note for the implementer:** every existing test file that builds a `ToolContext` object literal does so with `as ToolContext` (or `as never` / `{} as ToolContext`) — e.g. `test/unit/tools/passim.test.ts:8`. Because `ToolContext` is being widened (new required fields on the *target* type, not the literal), those casts stay valid TypeScript: a value with a superset of the literal's properties is still assignable to the literal's inferred type in the direction `as` checks. **Do not edit those test files** — if `pnpm typecheck` reports an error in one of them, something else is wrong; re-read this note rather than adding fields to those fixtures.

- [ ] **Step 1: Edit `registry.ts`**

```typescript
import type { Db } from '../db';
import type { WriteDb } from '../writedb';
import type { PendingReplyStore } from './pending-reply-store';
import type { Project, Source, ToolResult } from '../types';

export interface ToolContext {
  db: Db;
  writeDb: WriteDb;
  pendingReply: PendingReplyStore;
  repos: Record<Project, string>;
  now?: () => Date;
}
```

(Only the import block and the `ToolContext` interface change — `ToolSpec`, `AnthropicTool`, `escalateSpec`, `makeSource`, `measured`, and `ToolRegistry` are untouched.)

- [ ] **Step 2: Typecheck the whole project**

Run: `npx tsc --noEmit`
Expected: no errors. If an error appears in a test file under `test/unit/tools/` or `test/unit/session.test.ts` / `test/unit/brain.test.ts`, stop and re-read the note above before changing anything — those files are expected to keep compiling unmodified.

- [ ] **Step 3: Run the full unit suite**

Run: `npx vitest run`
Expected: PASS, same test count as before this task (this is a type-only change; no runtime behavior moved).

- [ ] **Step 4: Commit**

```bash
git add src/server/tools/registry.ts
git commit -m "feat: ToolContext gains writeDb and pendingReply"
```

---

### Task 6: `support_pending` tool

**Files:**
- Modify: `michelle/src/server/tools/format.ts`
- Modify: `michelle/test/unit/tools/format.test.ts`
- Create: `michelle/src/server/tools/support.ts`
- Create: `michelle/test/unit/tools/support.test.ts`

**Interfaces:**
- Consumes: `measured`, `ToolContext`, `ToolSpec` from `./registry`; `n` from `./format`; `Figure`, `ToolResult` from `../types`.
- Produces: `function truncate(s: string, max: number): string` (in `format.ts`); `function supportPending(): ToolSpec` — fast tier, no input, figures `[{ label: 'pending', value: <count> }]`, rows `{ ticket_id, email, latest_message, latest_message_at, days_open }[]`.

- [ ] **Step 1: Add the failing `truncate` test**

Add to `test/unit/tools/format.test.ts`, inside the existing `describe('format helpers', ...)` block:

```typescript
  it('truncate leaves short strings alone and adds an ellipsis past the limit', () => {
    expect(truncate('short', 10)).toBe('short');
    expect(truncate('exactly ten', 11)).toBe('exactly ten');
    expect(truncate('this is far too long', 10)).toBe('this is fa…');
  });
```

Update the import at the top of that file to `import { n, cents, neverHeldARow, notesOrUndefined, truncate } from '../../../src/server/tools/format';`.

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run test/unit/tools/format.test.ts`
Expected: FAIL — `truncate` is not exported.

- [ ] **Step 3: Implement `truncate` in `format.ts`**

Add to `src/server/tools/format.ts`:

```typescript
/** Cut a string to at most `max` characters, marking the cut with an ellipsis. */
export function truncate(s: string, max: number): string {
  return s.length > max ? `${s.slice(0, max)}…` : s;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npx vitest run test/unit/tools/format.test.ts`
Expected: PASS, all tests (existing 4 + new 1).

- [ ] **Step 5: Write the failing `support_pending` tests**

```typescript
import { describe, it, expect, vi } from 'vitest';
import { supportPending } from '../../../src/server/tools/support';
import type { ToolContext } from '../../../src/server/tools/registry';

function ctxWith(rows: Record<string, unknown>[]) {
  const select = vi.fn().mockResolvedValueOnce({ rows, rowCount: rows.length });
  return {
    ctx: {
      db: { select, close: async () => {} },
      writeDb: {} as never,
      pendingReply: {} as never,
      repos: { passim: '', palmacrew: '' },
      now: () => new Date(0),
    } as ToolContext,
    select,
  };
}

describe('support_pending', () => {
  it('reports the count and the rows, oldest first', async () => {
    const { ctx, select } = ctxWith([
      { ticket_id: 't1', email: 'a@x.com', latest_message: 'Where is my hotel?', latest_message_at: '2026-09-20T00:00:00.000Z', days_open: 8 },
      { ticket_id: 't2', email: 'b@x.com', latest_message: 'App crashes on open', latest_message_at: '2026-09-26T00:00:00.000Z', days_open: 2 },
    ]);
    const r = await supportPending().run({}, ctx);
    expect(select).toHaveBeenCalledOnce();
    expect(select.mock.calls[0][0]).toBe('passim');
    expect(select.mock.calls[0][1]).toMatch(/status = 'new'/);
    expect(r.figures).toEqual([{ label: 'pending', value: 2 }]);
    expect(r.rows).toEqual([
      { ticket_id: 't1', email: 'a@x.com', latest_message: 'Where is my hotel?', latest_message_at: '2026-09-20T00:00:00.000Z', days_open: 8 },
      { ticket_id: 't2', email: 'b@x.com', latest_message: 'App crashes on open', latest_message_at: '2026-09-26T00:00:00.000Z', days_open: 2 },
    ]);
    expect(r.source).toMatchObject({ kind: 'measured', project: 'passim' });
  });

  it('reports zero pending as a figure, not an empty result', async () => {
    const { ctx } = ctxWith([]);
    const r = await supportPending().run({}, ctx);
    expect(r.figures).toEqual([{ label: 'pending', value: 0 }]);
    expect(r.rows).toEqual([]);
  });

  it('truncates a long message to 200 characters', async () => {
    const long = 'x'.repeat(250);
    const { ctx } = ctxWith([{ ticket_id: 't1', email: 'a@x.com', latest_message: long, latest_message_at: '2026-09-20T00:00:00.000Z', days_open: 1 }]);
    const r = await supportPending().run({}, ctx);
    expect((r.rows![0].latest_message as string).length).toBe(201); // 200 chars + ellipsis
  });
});
```

- [ ] **Step 6: Run test to verify it fails**

Run: `npx vitest run test/unit/tools/support.test.ts`
Expected: FAIL — cannot find module `../../../src/server/tools/support`.

- [ ] **Step 7: Implement `support.ts` (first export only)**

```typescript
import type { Figure, ToolResult } from '../types';
import { measured, type ToolContext, type ToolSpec } from './registry';
import { n, truncate } from './format';

const PENDING_SQL = `
select t.id as ticket_id, t.email, m.body as latest_message, m.created_at as latest_message_at,
       extract(day from now() - m.created_at)::int as days_open
from support_tickets t
join lateral (
  select body, created_at from support_messages sm
  where sm.ticket_id = t.id and sm.author = 'customer'
  order by sm.created_at desc
  limit 1
) m on true
where t.status = 'new'
order by m.created_at asc`;

export function supportPending(): ToolSpec {
  return {
    name: 'support_pending', tier: 'fast',
    description:
      'Passim support tickets waiting for a reply — the newest message on each is from the customer and nobody ' +
      'has answered yet. Oldest first. Use for "any support tickets", "check support", or as part of a daily briefing.',
    input_schema: { type: 'object', properties: {} },
    async run(_input, ctx: ToolContext): Promise<ToolResult> {
      const { value: rows, source } = await measured('passim', ctx, async () => (await ctx.db.select('passim', PENDING_SQL)).rows);
      const figures: Figure[] = [{ label: 'pending', value: rows.length }];
      return {
        figures,
        rows: rows.map((r) => ({
          ticket_id: r.ticket_id,
          email: r.email,
          latest_message: truncate(String(r.latest_message), 200),
          latest_message_at: r.latest_message_at,
          days_open: n(r.days_open),
        })),
        source,
      };
    },
  };
}
```

- [ ] **Step 8: Run test to verify it passes**

Run: `npx vitest run test/unit/tools/support.test.ts test/unit/tools/format.test.ts`
Expected: PASS, all tests.

- [ ] **Step 9: Commit**

```bash
git add src/server/tools/format.ts test/unit/tools/format.test.ts src/server/tools/support.ts test/unit/tools/support.test.ts
git commit -m "feat: support_pending — read-only queue of unanswered tickets"
```

---

### Task 7: `propose_support_reply` and `send_support_reply`

**Files:**
- Modify: `michelle/src/server/tools/support.ts`
- Modify: `michelle/test/unit/tools/support.test.ts`

**Interfaces:**
- Consumes: `ctx.pendingReply: PendingReplyStore` (Task 2), `ctx.writeDb: WriteDb` (Task 3).
- Produces: `function proposeSupportReply(): ToolSpec` — broad tier, input `{ ticket_id: string, body: string }` (both required); `function sendSupportReply(): ToolSpec` — broad tier, input `{ ticket_id: string }` only, **no `body` field**.

- [ ] **Step 1: Write the failing tests**

Add to `test/unit/tools/support.test.ts`:

```typescript
import { proposeSupportReply, sendSupportReply } from '../../../src/server/tools/support';
import { PendingReplyStore } from '../../../src/server/tools/pending-reply-store';

function ctxForWrite(pendingReply = new PendingReplyStore()) {
  const insertSupportReply = vi.fn(async (ticketId: string, body: string) => ({ id: 'msg-1' }));
  return {
    ctx: {
      db: {} as never,
      writeDb: { insertSupportReply, close: async () => {} },
      pendingReply,
      repos: { passim: '', palmacrew: '' },
      now: () => new Date('2026-09-28T10:00:00.000Z'),
    } as ToolContext,
    insertSupportReply,
    pendingReply,
  };
}

describe('propose_support_reply', () => {
  it('has no body limit escape hatch: rejects text outside 1-4000 chars', async () => {
    const { ctx } = ctxForWrite();
    await expect(proposeSupportReply().run({ ticket_id: 't1', body: '' }, ctx)).rejects.toThrow(/1-4000/);
    await expect(proposeSupportReply().run({ ticket_id: 't1', body: 'x'.repeat(4001) }, ctx)).rejects.toThrow(/1-4000/);
  });

  it('stages the draft without writing to the database and echoes it as text', async () => {
    const { ctx, insertSupportReply, pendingReply } = ctxForWrite();
    const r = await proposeSupportReply().run({ ticket_id: 't1', body: 'We are on it.' }, ctx);
    expect(insertSupportReply).not.toHaveBeenCalled();
    expect(pendingReply.get()).toEqual({ ticketId: 't1', body: 'We are on it.', proposedAt: '2026-09-28T10:00:00.000Z' });
    expect(r.text).toBe('We are on it.');
    expect(r.source.kind).toBe('read');
  });

  it('replaces an earlier draft for a different ticket', async () => {
    const { ctx, pendingReply } = ctxForWrite();
    await proposeSupportReply().run({ ticket_id: 't1', body: 'first' }, ctx);
    await proposeSupportReply().run({ ticket_id: 't2', body: 'second' }, ctx);
    expect(pendingReply.get()).toMatchObject({ ticketId: 't2', body: 'second' });
  });
});

describe('send_support_reply', () => {
  it('has no way to receive new text: its schema has no body property', () => {
    expect(sendSupportReply().input_schema.properties).not.toHaveProperty('body');
    expect(Object.keys(sendSupportReply().input_schema.properties)).toEqual(['ticket_id']);
  });

  it('refuses to send when nothing has been proposed', async () => {
    const { ctx } = ctxForWrite();
    await expect(sendSupportReply().run({ ticket_id: 't1' }, ctx)).rejects.toThrow(/nothing has been proposed/i);
  });

  it('refuses to send a different ticket than what is pending', async () => {
    const { ctx, pendingReply, insertSupportReply } = ctxForWrite();
    pendingReply.propose('t1', 'We are on it.');
    await expect(sendSupportReply().run({ ticket_id: 't2' }, ctx)).rejects.toThrow(/different ticket/i);
    expect(insertSupportReply).not.toHaveBeenCalled();
  });

  it('sends exactly the staged body and clears the slot', async () => {
    const { ctx, pendingReply, insertSupportReply } = ctxForWrite();
    pendingReply.propose('t1', 'We are on it.');
    const r = await sendSupportReply().run({ ticket_id: 't1' }, ctx);
    expect(insertSupportReply).toHaveBeenCalledWith('t1', 'We are on it.');
    expect(pendingReply.get()).toBeNull();
    expect(r.figures).toEqual([{ label: 'sent', value: 1 }]);
    expect(r.notes).toEqual(['Reply sent to ticket t1.']);
  });

  it('ignores any body-shaped field a caller sneaks into input — only ticket_id is read', async () => {
    const { ctx, pendingReply, insertSupportReply } = ctxForWrite();
    pendingReply.propose('t1', 'We are on it.');
    await sendSupportReply().run({ ticket_id: 't1', body: 'something else entirely' } as never, ctx);
    expect(insertSupportReply).toHaveBeenCalledWith('t1', 'We are on it.');
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run test/unit/tools/support.test.ts`
Expected: FAIL — `proposeSupportReply` and `sendSupportReply` are not exported.

- [ ] **Step 3: Implement both tools**

Add to `src/server/tools/support.ts` (after `supportPending`):

```typescript
export function proposeSupportReply(): ToolSpec {
  return {
    name: 'propose_support_reply', tier: 'broad',
    description:
      'Stage a reply to a support ticket so the owner can hear it before it sends. Call this, say the body out ' +
      'loud, then wait for the owner to approve before calling send_support_reply. Never call send_support_reply ' +
      'without a clear, specific yes to this exact proposal.',
    input_schema: {
      type: 'object',
      properties: {
        ticket_id: { type: 'string', description: 'The ticket id, from support_pending.' },
        body: { type: 'string', description: 'The exact reply text, 1-4000 characters, written as "Passim Support" — never mention Michelle or AI.' },
      },
      required: ['ticket_id', 'body'],
    },
    async run(input, ctx: ToolContext): Promise<ToolResult> {
      const ticketId = String(input.ticket_id ?? '');
      const bodyIn = String(input.body ?? '');
      if (bodyIn.length < 1 || bodyIn.length > 4000) throw new Error('body must be 1-4000 characters');
      const now = ctx.now ?? (() => new Date());
      const { value: body, source } = await measured(
        'passim', ctx,
        async () => { ctx.pendingReply.propose(ticketId, bodyIn, now()); return bodyIn; },
        'read'
      );
      return { figures: [], text: body, source };
    },
  };
}

export function sendSupportReply(): ToolSpec {
  return {
    name: 'send_support_reply', tier: 'broad',
    description:
      'Send the reply already proposed and approved for this ticket. There is no way to pass new text here — it ' +
      'can only send exactly what propose_support_reply staged. Only call this after the owner has clearly said yes.',
    input_schema: {
      type: 'object',
      properties: { ticket_id: { type: 'string', description: 'The ticket id that was just approved.' } },
      required: ['ticket_id'],
    },
    async run(input, ctx: ToolContext): Promise<ToolResult> {
      const ticketId = String(input.ticket_id ?? '');
      const pending = ctx.pendingReply.get();
      if (!pending) throw new Error('Nothing has been proposed yet — propose a reply first.');
      if (pending.ticketId !== ticketId) throw new Error('The pending draft is for a different ticket.');
      const { value, source } = await measured('passim', ctx, async () => ctx.writeDb.insertSupportReply(pending.ticketId, pending.body));
      ctx.pendingReply.clear();
      return {
        figures: [{ label: 'sent', value: 1 }],
        notes: [`Reply sent to ticket ${pending.ticketId}.`],
        source,
      };
    },
  };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npx vitest run test/unit/tools/support.test.ts`
Expected: PASS, all tests (Task 6's 3 + this task's 9).

- [ ] **Step 5: Commit**

```bash
git add src/server/tools/support.ts test/unit/tools/support.test.ts
git commit -m "feat: propose_support_reply / send_support_reply — send cannot substitute text"
```

---

### Task 8: Wire the new tools into the server

**Files:**
- Modify: `michelle/src/server/index.ts`
- Modify: `michelle/src/server/brain.ts`

**Interfaces:**
- Consumes: `createWriteDb` (Task 3), `PendingReplyStore` (Task 2), `supportPending`, `proposeSupportReply`, `sendSupportReply` (Tasks 6–7), `config.passimWriteDbUrl` (Task 4).

- [ ] **Step 1: Edit `index.ts`**

Change the import block:

```typescript
import { createDb } from './db';
import { createWriteDb } from './writedb';
```

```typescript
import { ToolRegistry, escalateSpec, type ToolContext } from './tools/registry';
import { PendingReplyStore } from './tools/pending-reply-store';
import { passimContent, passimAudience, passimBusiness } from './tools/passim';
import { supportPending, proposeSupportReply, sendSupportReply } from './tools/support';
```

Change the context and tool wiring:

```typescript
const config = loadConfig();
const db = createDb(config.dbUrls);
const writeDb = createWriteDb(config.passimWriteDbUrl);
const ctx: ToolContext = { db, writeDb, pendingReply: new PendingReplyStore(), repos: config.repos };

const tools = new ToolRegistry();
const fast = [passimContent(), passimAudience(), passimBusiness(), palmacrewMarket(), palmacrewMoney(), supportPending()];
fast.forEach((t) => tools.register(t));
tools.register(dailyBriefing({ fast }));
tools.register(escalateSpec());
[queryTool(), readRepoTool(), searchRepoTool(), gitLogTool(), proposeSupportReply(), sendSupportReply()].forEach((t) => tools.register(t));
```

Change the startup log:

```typescript
server.listen(config.port, '127.0.0.1', () => {
  const missing = (['passim', 'palmacrew'] as const).filter((p) => !config.dbUrls[p]);
  console.log(`Michelle listening on http://127.0.0.1:${config.port}  (ws at /ws)`);
  if (missing.length) console.log(`No database url for: ${missing.join(', ')} — those briefings will report unavailable.`);
  if (!config.passimWriteDbUrl) console.log('No MICHELLE_PASSIM_WRITE_DB_URL — sending support replies will report unavailable.');
});
```

Change the shutdown handler:

```typescript
process.on('SIGINT', async () => { await db.close(); await writeDb.close(); process.exit(0); });
```

- [ ] **Step 2: Append the new system-prompt rules in `brain.ts`**

In the `SYSTEM` template string, immediately before the closing backtick (after the existing "Money in the databases..." line), add:

```typescript
- You can now propose and send replies to Passim support tickets. Read the ticket for yourself before proposing anything — never invent what a customer said.
- Never send without proposing first in this same conversation, and never send unless the owner's most recent reply is a clear, specific yes to that exact proposal. A vague or ambiguous reply is a no — ask again rather than guess.
- One ticket at a time. If the owner says no, drop it — do not re-propose automatically or ask what to say instead.
- The reply's content is written as "Passim Support" — never mention Michelle, AI, or being an assistant inside the reply text itself.
```

(The four new lines are added inside the existing template literal, before its closing backtick-semicolon.)

- [ ] **Step 3: Typecheck and run the full unit suite**

Run: `npx tsc --noEmit && npx vitest run`
Expected: no type errors; all unit tests pass (`test/unit/brain.test.ts` checks specific SYSTEM-prompt-adjacent behavior like the escalate phrase, not the prompt's literal text, so it should be unaffected — confirm this by reading its failures, if any, rather than assuming).

- [ ] **Step 4: Manual smoke check**

```bash
npx tsc --noEmit
npx vite build
```

Expected: both succeed with no errors (this catches anything the unit tests wouldn't, like an unused-import issue in `index.ts`).

- [ ] **Step 5: Commit**

```bash
git add src/server/index.ts src/server/brain.ts
git commit -m "feat: wire support_pending/propose/send into the server and the system prompt"
```

---

### Task 9: Integration test for the `michelle_rw` role

**Files:**
- Create: `michelle/test/integration/writedb.int.test.ts`

**Interfaces:**
- Consumes: `MICHELLE_PASSIM_WRITE_DB_URL` and `MICHELLE_PASSIM_DB_URL` from the environment (both optional at test-collection time — the whole suite skips if either is missing).

This is the load-bearing test for this sub-project (spec §9): it proves against the real database that `michelle_rw` can do exactly one thing. It will skip (not fail) until the owner applies migration 048 and sets `MICHELLE_PASSIM_WRITE_DB_URL` (Task 1, Step 4) — that is expected and correct.

- [ ] **Step 1: Write the test**

```typescript
import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { Client } from 'pg';
import 'dotenv/config';

const writeUrl = process.env.MICHELLE_PASSIM_WRITE_DB_URL;
const readUrl = process.env.MICHELLE_PASSIM_DB_URL;

describe.skipIf(!writeUrl || !readUrl)('michelle_rw on passim', () => {
  const write = new Client({ connectionString: writeUrl, ssl: { rejectUnauthorized: false } });
  const read = new Client({ connectionString: readUrl, ssl: { rejectUnauthorized: false } });
  let ticketId: string;

  beforeAll(async () => {
    await write.connect();
    await read.connect();
    const r = await read.query('select id from public.support_tickets limit 1');
    if (r.rows.length === 0) throw new Error('no support_tickets row exists to test against — create one ticket first');
    ticketId = r.rows[0].id;
  });

  afterAll(async () => {
    await write.end();
    await read.end();
  });

  it('is refused a SELECT', async () => {
    await expect(write.query('select id from public.support_messages limit 1')).rejects.toThrow(/permission denied/i);
  });

  it('is refused an UPDATE', async () => {
    await expect(write.query(`update public.support_messages set body = 'x' where false`)).rejects.toThrow(/permission denied/i);
  });

  it('is refused a DELETE', async () => {
    await expect(write.query(`delete from public.support_messages where false`)).rejects.toThrow(/permission denied/i);
  });

  it('is refused an insert with an author other than michelle', async () => {
    await expect(
      write.query(`insert into public.support_messages (ticket_id, author, body) values ($1, 'staff', 'x')`, [ticketId])
    ).rejects.toThrow(/policy/i);
  });

  it('is refused an insert with a non-null author_user_id', async () => {
    await expect(
      write.query(
        `insert into public.support_messages (ticket_id, author, author_user_id, body) values ($1, 'michelle', gen_random_uuid(), 'x')`,
        [ticketId]
      )
    ).rejects.toThrow(/policy/i);
  });

  it('allows the one permitted shape, and the row is visible via the read role', async () => {
    const marker = `integration test ${new Date().toISOString()}`;
    const ins = await write.query(
      `insert into public.support_messages (ticket_id, author, body) values ($1, 'michelle', $2) returning id`,
      [ticketId, marker]
    );
    expect(ins.rows[0].id).toBeTruthy();
    const back = await read.query('select author, body from public.support_messages where id = $1', [ins.rows[0].id]);
    expect(back.rows[0]).toEqual({ author: 'michelle', body: marker });
  });

  it('is not a superuser', async () => {
    const r = await write.query(`select rolsuper from pg_roles where rolname = current_user`);
    expect(r.rows[0].rolsuper).toBe(false);
  });
});
```

- [ ] **Step 2: Run it now (expected to skip)**

Run: `cd C:/Users/tilly/michelle && npx cross-env MICHELLE_INTEGRATION=1 vitest run test/integration/writedb.int.test.ts`
Expected: the suite is skipped (0 run) because `MICHELLE_PASSIM_WRITE_DB_URL` is not yet set in this environment. This is correct — do not treat it as a failure and do not add a fallback URL to make it run.

- [ ] **Step 3: Commit**

```bash
git add test/integration/writedb.int.test.ts
git commit -m "test(int): michelle_rw can only insert author='michelle', nothing else"
```

- [ ] **Step 4: Owner step — run for real**

Once Task 1 Step 4 is done (migration applied, `.env` has `MICHELLE_PASSIM_WRITE_DB_URL`), owner runs:

```bash
pnpm test:int
```

Expected: the `michelle_rw on passim` suite runs (not skipped) and all 7 tests pass. This leaves one real test row in production `support_messages` (author `michelle`, body starting `integration test `) — harmless, and visible in the admin thread for whichever ticket was picked.

---

### Task 10: Owner verification (manual, live)

Not a code task — do this after Tasks 1–9 are committed and the owner has completed Task 1 Step 4 and Task 9 Step 4.

- [ ] Start Michelle (`pnpm dev`) with `MICHELLE_PASSIM_WRITE_DB_URL` set.
- [ ] Ask "do we have any support tickets" — confirm she reports the same count `support_pending` would (cross-check against the admin support page or a direct SQL count of `status = 'new'`).
- [ ] Pick one real pending ticket. Ask her to look at it and propose a reply. Confirm the proposed text is read back to you in full before you answer.
- [ ] Say a clear "yes, send it." Confirm she confirms it sent. Open the admin thread (or the app, once installed) for that ticket and confirm the reply appears, attributed as "Passim Support" (not "Michelle" or "staff" anywhere in the visible text), and the ticket's status flipped to `answered`.
- [ ] Repeat with a second ticket, but say "no" to the proposal. Confirm nothing was sent (ticket status unchanged, no new row in the admin thread) and she does not re-propose on her own.
- [ ] Confirm the daily briefing (`daily_briefing`) now mentions a `support_pending · pending` figure when tickets are waiting.
