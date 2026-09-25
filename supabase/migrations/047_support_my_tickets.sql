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
