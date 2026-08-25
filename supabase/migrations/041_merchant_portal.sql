-- Merchant self-service portal access. Merchants sign in with a normal
-- account linked to their merchants row (owner_user_id); they never get an
-- admin role and never see admin data. They may read their own deals and
-- pause/resume them — nothing else is writable from their side.

-- Am I the owner of at least one merchant?
create or replace function public.is_merchant()
returns boolean language sql security definer stable as $$
  select exists (
    select 1 from public.merchants where owner_user_id = auth.uid()
  );
$$;
grant execute on function public.is_merchant() to authenticated;

-- Their own deals (hot_deals already has a public read policy for the app;
-- this makes the intent explicit and survives a future tightening).
create policy "merchant_read_own_deals" on public.hot_deals
  for select using (exists (
    select 1 from public.merchants m
    where m.id = merchant_id and m.owner_user_id = auth.uid()
  ));

-- Pause / resume — the only write a merchant gets, via RPC so no broad
-- UPDATE policy on hot_deals is needed.
create or replace function public.merchant_set_deal_active(
  p_deal_id uuid, p_active boolean
) returns void
language plpgsql security definer set search_path = public as $$
declare v_credit int;
begin
  select m.credit_cents into v_credit
    from hot_deals d join merchants m on m.id = d.merchant_id
    where d.id = p_deal_id and m.owner_user_id = auth.uid();
  if not found then raise exception 'not your deal'; end if;
  if p_active and v_credit <= 0 then
    raise exception 'no credit left — top up to run this deal';
  end if;
  update hot_deals set is_active = p_active where id = p_deal_id;
end;
$$;
revoke all on function public.merchant_set_deal_active(uuid, boolean) from public;
grant execute on function public.merchant_set_deal_active(uuid, boolean) to authenticated;

-- Aggregate performance for the merchant dashboard. Returns counts only —
-- never any individual explorer's identity or position.
create or replace function public.merchant_deal_stats()
returns table (deal_id uuid, reached bigint, redeemed bigint)
language sql security definer stable set search_path = public as $$
  select d.id,
         (select count(*) from deal_reach r where r.deal_id = d.id),
         (select count(*) from deal_redemptions x
            where x.deal_id = d.id and x.status in ('redeemed', 'shown'))
  from hot_deals d
  join merchants m on m.id = d.merchant_id
  where m.owner_user_id = auth.uid();
$$;
grant execute on function public.merchant_deal_stats() to authenticated;
