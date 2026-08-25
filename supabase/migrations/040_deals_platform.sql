-- Deals platform v1: merchants + credit wallet, rich deal content,
-- one-time redemption codes (scan + show modes), reach logging and
-- per-event billing (push reach = 5 cents, validated redemption = 50 cents).
-- Merchants are created manually by admins; merchant staff sign in with a
-- normal account that the admin links + grants the 'business_owner' role.

-- ============================================================
-- MERCHANTS
-- ============================================================
create table public.merchants (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  contact_email text,
  owner_user_id uuid references auth.users(id) on delete set null,
  credit_cents int not null default 0,
  created_at timestamptz not null default now()
);
alter table public.merchants enable row level security;
create policy "admin_all_merchants" on public.merchants
  for all using (public.is_admin()) with check (public.is_admin());
create policy "owner_read_merchant" on public.merchants
  for select using (owner_user_id = auth.uid());

-- ============================================================
-- RICHER DEALS (hotspot-parity content)
-- ============================================================
alter table public.hot_deals
  add column merchant_id uuid references public.merchants(id) on delete set null,
  add column description text,
  add column header_image text,
  add column category text not null default 'restaurant',
  add column redeem_mode text not null default 'show'
    check (redeem_mode in ('scan', 'show'));

create table public.deal_media (
  id uuid primary key default gen_random_uuid(),
  deal_id uuid not null references public.hot_deals(id) on delete cascade,
  media_type text not null default 'image',
  storage_path text not null,
  sort_order int not null default 0,
  caption text
);
alter table public.deal_media enable row level security;
create policy "public_read_deal_media" on public.deal_media
  for select using (true);
create policy "admin_all_deal_media" on public.deal_media
  for all using (public.is_admin()) with check (public.is_admin());

-- ============================================================
-- REDEMPTIONS (one-time codes)
-- ============================================================
create table public.deal_redemptions (
  id uuid primary key default gen_random_uuid(),
  deal_id uuid not null references public.hot_deals(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  user_key text,                     -- anon install id (guests)
  code text not null unique,
  status text not null default 'issued'
    check (status in ('issued', 'shown', 'redeemed', 'expired')),
  issued_at timestamptz not null default now(),
  redeemed_at timestamptz,
  expires_at timestamptz not null
);
create index deal_redemptions_deal on public.deal_redemptions(deal_id);
alter table public.deal_redemptions enable row level security;
create policy "own_redemptions" on public.deal_redemptions
  for select using (user_id = auth.uid());
create policy "merchant_read_redemptions" on public.deal_redemptions
  for select using (exists (
    select 1 from public.hot_deals d
    join public.merchants m on m.id = d.merchant_id
    where d.id = deal_id and m.owner_user_id = auth.uid()
  ));
create policy "admin_read_redemptions" on public.deal_redemptions
  for select using (public.is_admin());

-- ============================================================
-- REACH LOG (one billable row per person, per deal, per day)
-- ============================================================
create table public.deal_reach (
  deal_id uuid not null references public.hot_deals(id) on delete cascade,
  user_key text not null,            -- anon install id
  day date not null default current_date,
  reached_at timestamptz not null default now(),
  primary key (deal_id, user_key, day)
);
alter table public.deal_reach enable row level security;
create policy "merchant_read_reach" on public.deal_reach
  for select using (exists (
    select 1 from public.hot_deals d
    join public.merchants m on m.id = d.merchant_id
    where d.id = deal_id and m.owner_user_id = auth.uid()
  ));
create policy "admin_read_reach" on public.deal_reach
  for select using (public.is_admin());

-- ============================================================
-- CREDIT LEDGER (every cent in/out is one auditable row)
-- ============================================================
create table public.credit_ledger (
  id uuid primary key default gen_random_uuid(),
  merchant_id uuid not null references public.merchants(id) on delete cascade,
  delta_cents int not null,          -- positive = top-up, negative = charge
  reason text not null,              -- 'topup' | 'reach' | 'redemption' | 'adjustment'
  ref_id uuid,                       -- the deal/redemption this charge refers to
  note text,
  created_at timestamptz not null default now()
);
create index credit_ledger_merchant on public.credit_ledger(merchant_id, created_at desc);
alter table public.credit_ledger enable row level security;
create policy "admin_read_ledger" on public.credit_ledger
  for select using (public.is_admin());
create policy "owner_read_ledger" on public.credit_ledger
  for select using (exists (
    select 1 from public.merchants m
    where m.id = merchant_id and m.owner_user_id = auth.uid()
  ));

-- ============================================================
-- BILLING CORE (internal)
-- ============================================================
create or replace function public._deal_debit(
  p_merchant_id uuid, p_amount_cents int, p_reason text, p_ref uuid
) returns void
language plpgsql security definer set search_path = public as $$
declare v_credit int;
begin
  if p_merchant_id is null then return; end if;
  insert into credit_ledger (merchant_id, delta_cents, reason, ref_id)
    values (p_merchant_id, -p_amount_cents, p_reason, p_ref);
  update merchants set credit_cents = credit_cents - p_amount_cents
    where id = p_merchant_id
    returning credit_cents into v_credit;
  -- Out of credit: auto-pause every deal for this merchant.
  if v_credit <= 0 then
    update hot_deals set is_active = false where merchant_id = p_merchant_id;
  end if;
end;
$$;
revoke all on function public._deal_debit(uuid, int, text, uuid) from public;

-- ============================================================
-- RPC: explorer taps "Redeem" — issue a one-time code (15 min)
-- ============================================================
create or replace function public.deal_redeem_start(p_deal_id uuid, p_user_key text)
returns json
language plpgsql security definer set search_path = public as $$
declare
  v_deal hot_deals%rowtype;
  v_code text;
  v_expires timestamptz := now() + interval '15 minutes';
  v_status text;
begin
  select * into v_deal from hot_deals where id = p_deal_id and is_active;
  if not found then return json_build_object('error', 'deal_inactive'); end if;

  -- 6-char human-friendly code (hex-based, 0/1 swapped out so no 0/O/1/I).
  v_code := upper(substr(translate(
    md5(gen_random_uuid()::text || clock_timestamp()::text), '01', 'XY'), 1, 6));
  -- 'show' mode counts the tap itself as the redemption stat (free);
  -- 'scan' mode stays 'issued' until the merchant validates it.
  v_status := case when v_deal.redeem_mode = 'show' then 'shown' else 'issued' end;

  insert into deal_redemptions (deal_id, user_id, user_key, code, status, expires_at)
    values (p_deal_id, auth.uid(), p_user_key, v_code, v_status, v_expires);

  return json_build_object(
    'code', v_code,
    'expires_at', v_expires,
    'mode', v_deal.redeem_mode,
    'business', v_deal.business_name,
    'offer', v_deal.offer_text
  );
end;
$$;
revoke all on function public.deal_redeem_start(uuid, text) from public;
grant execute on function public.deal_redeem_start(uuid, text) to anon, authenticated;

-- ============================================================
-- RPC: merchant/admin validates a scanned or typed code
-- ============================================================
create or replace function public.deal_redeem_validate(p_code text)
returns json
language plpgsql security definer set search_path = public as $$
declare
  v_r deal_redemptions%rowtype;
  v_deal hot_deals%rowtype;
  v_allowed boolean;
begin
  select * into v_r from deal_redemptions where code = upper(trim(p_code));
  if not found then return json_build_object('status', 'invalid'); end if;
  select * into v_deal from hot_deals where id = v_r.deal_id;

  v_allowed := public.is_admin() or exists (
    select 1 from merchants m
    where m.id = v_deal.merchant_id and m.owner_user_id = auth.uid());
  if not v_allowed then return json_build_object('status', 'not_allowed'); end if;

  if v_r.status = 'redeemed' then
    return json_build_object('status', 'used', 'redeemed_at', v_r.redeemed_at,
      'business', v_deal.business_name, 'offer', v_deal.offer_text);
  end if;
  if v_r.expires_at < now() then
    update deal_redemptions set status = 'expired' where id = v_r.id;
    return json_build_object('status', 'expired',
      'business', v_deal.business_name, 'offer', v_deal.offer_text);
  end if;

  update deal_redemptions
    set status = 'redeemed', redeemed_at = now() where id = v_r.id;
  -- Only scan-validated redemptions are billed (50 cents).
  perform public._deal_debit(v_deal.merchant_id, 50, 'redemption', v_r.id);

  return json_build_object('status', 'valid',
    'business', v_deal.business_name, 'offer', v_deal.offer_text);
end;
$$;
revoke all on function public.deal_redeem_validate(text) from public;
grant execute on function public.deal_redeem_validate(text) to authenticated;

-- ============================================================
-- RPC: app logs a delivered deal notification (5 cents, once/day/person)
-- ============================================================
create or replace function public.deal_reach_log(p_deal_id uuid, p_user_key text)
returns void
language plpgsql security definer set search_path = public as $$
declare v_merchant uuid;
begin
  if p_user_key is null or length(p_user_key) < 8 then return; end if;
  select merchant_id into v_merchant
    from hot_deals where id = p_deal_id and is_active;
  if not found then return; end if;

  insert into deal_reach (deal_id, user_key) values (p_deal_id, p_user_key)
    on conflict do nothing;
  if found then
    perform public._deal_debit(v_merchant, 5, 'reach', p_deal_id);
  end if;
end;
$$;
revoke all on function public.deal_reach_log(uuid, text) from public;
grant execute on function public.deal_reach_log(uuid, text) to anon, authenticated;

-- ============================================================
-- RPC: admin tops up a merchant's credit (manual billing for now)
-- ============================================================
create or replace function public.merchant_topup(
  p_merchant_id uuid, p_amount_cents int, p_note text default null
) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'not an admin'; end if;
  insert into credit_ledger (merchant_id, delta_cents, reason, note)
    values (p_merchant_id, p_amount_cents, 'topup', p_note);
  update merchants set credit_cents = credit_cents + p_amount_cents
    where id = p_merchant_id;
end;
$$;
revoke all on function public.merchant_topup(uuid, int, text) from public;
grant execute on function public.merchant_topup(uuid, int, text) to authenticated;
