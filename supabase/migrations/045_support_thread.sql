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
