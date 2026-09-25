-- 047_support_my_tickets.sql — list a device's support conversations.
-- Idempotent. Run in Supabase → SQL Editor as the default (postgres) user.
--
-- Companion to 045's support_thread / support_reply: same trust model
-- (knowing an install_id grants access to that device's tickets), same
-- 'not found' for a null or short id. last_* describe the newest message.
--
-- This file also adds the trigger that gives every NEW ticket its own
-- first message (045's backfill only covered tickets that existed when
-- it ran) — without it, every ticket created after 045 would open as a
-- permanently empty thread. A ticket can still have zero messages only
-- if its own text violates the 1-4000 char check (the same edge case
-- 045's backfill already accepted).

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

-- ------------------------------------------------------------
-- Every ticket gets its own first message automatically. security
-- definer because anon has no insert policy on support_messages —
-- a plain trigger would fail under RLS and take the ticket insert
-- down with it. Mirrors support_messages_set_status's own pattern.
-- ------------------------------------------------------------
create or replace function public.support_tickets_first_message()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if length(new.message) between 1 and 4000 then
    insert into public.support_messages (ticket_id, author, body, created_at)
    values (new.id, 'customer', new.message, new.created_at);
  end if;
  return new;
end $$;

drop trigger if exists support_tickets_first_message on public.support_tickets;
create trigger support_tickets_first_message
  after insert on public.support_tickets
  for each row execute function public.support_tickets_first_message();

-- Catch-up for tickets created between 045's one-time backfill and this
-- trigger going live. Guarded on "no CUSTOMER row" (not "no row at all")
-- so a ticket that already picked up a staff reply, but never got its
-- own first message, still gets one. The status trigger is disabled
-- around this insert for the same reason 045's backfill disables it:
-- a ticket already 'answered' or 'closed' must not be reset to 'new'.
alter table public.support_messages disable trigger support_messages_set_status;
insert into public.support_messages (ticket_id, author, body, created_at)
select t.id, 'customer', t.message, t.created_at
  from public.support_tickets t
 where length(t.message) between 1 and 4000
   and not exists (
     select 1 from public.support_messages m
     where m.ticket_id = t.id and m.author = 'customer'
   );
alter table public.support_messages enable trigger support_messages_set_status;
