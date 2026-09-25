-- 046_support_ticket_owner_select.sql — let a signed-in customer read their own tickets.
--
-- Why: 045's customer policies on support_messages decide access with
--   exists (select 1 from support_tickets t where t.id = ticket_id and t.user_id = auth.uid())
-- and that subquery is itself subject to RLS on support_tickets, which (026) only
-- lets admins select. For a non-admin the subquery sees nothing, so the customer
-- policies never match. This policy is what makes them work — and what the app's
-- "my tickets" list (sub-project C) needs anyway.
-- Idempotent.

drop policy if exists support_tickets_owner_select on public.support_tickets;
create policy support_tickets_owner_select on public.support_tickets
  for select to authenticated
  using (user_id = auth.uid());
