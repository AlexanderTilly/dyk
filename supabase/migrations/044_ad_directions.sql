-- ============================================================
-- "Take me there" on an ad, and the numbers to sell it with.
--
-- An advertiser's first question is "how many people did you send me".
-- That can only be answered if it was counted from the start, so the
-- counting ships with the button rather than after it.
-- ============================================================

-- ------------------------------------------------------------
-- 1. The door, which is not where the ad is shown
-- ------------------------------------------------------------
-- target_lat/lng already exist and mean "show this ad to people near
-- here", together with radius_km. That is an area, and navigating to the
-- centre of an area puts a tourist on the wrong street. The destination
-- is its own thing.
alter table public.internal_ads
  add column if not exists dest_lat double precision,
  add column if not exists dest_lng double precision,
  add column if not exists dest_label text;

comment on column public.internal_ads.dest_lat is
  'The venue door. Separate from target_lat, which is where the ad is shown.';

-- Which merchant this ad belongs to, so events can be attributed — and,
-- one day, billed. Nullable: existing ads are house ads with no owner.
-- Added now because attribution cannot be backfilled; the price is a
-- decision that can wait, the history cannot.
alter table public.internal_ads
  add column if not exists merchant_id uuid references public.merchants(id) on delete set null;

-- ------------------------------------------------------------
-- 2. Events
-- ------------------------------------------------------------
-- Shaped like deal_reach: the primary key makes a row mean "this person,
-- this ad, this kind, today". Tapping five times is one row, so the
-- number is people rather than taps — which is the number an advertiser
-- can be invoiced on without argument.
create table if not exists public.ad_events (
  ad_id uuid not null references public.internal_ads(id) on delete cascade,
  user_key text not null,            -- anon install id
  kind text not null check (kind in ('directions', 'arrival')),
  day date not null default current_date,
  created_at timestamptz not null default now(),
  primary key (ad_id, user_key, kind, day)
);

alter table public.ad_events enable row level security;

create policy "admin_read_ad_events" on public.ad_events
  for select using (public.is_admin());

create policy "merchant_read_own_ad_events" on public.ad_events
  for select using (exists (
    select 1 from public.internal_ads a
    join public.merchants m on m.id = a.merchant_id
    where a.id = ad_id and m.owner_user_id = auth.uid()
  ));

create index if not exists ad_events_ad_kind_idx
  on public.ad_events (ad_id, kind, day desc);

-- ------------------------------------------------------------
-- 3. Logging
-- ------------------------------------------------------------
-- No debit. The events are recorded so the volume is known before a
-- price is put on it; pricing something nobody has measured is guessing.
-- When that changes, this is where a _deal_debit call goes.
create or replace function public.ad_event_log(
  p_ad_id uuid,
  p_user_key text,
  p_kind text
)
returns void
language plpgsql security definer set search_path = public as $$
begin
  -- Junk keys are dropped silently: a client that has not finished
  -- setting itself up should not be able to write rows.
  if p_user_key is null or length(p_user_key) < 8 then return; end if;
  if p_kind not in ('directions', 'arrival') then return; end if;
  if not exists (select 1 from internal_ads where id = p_ad_id and is_active) then
    return;
  end if;

  insert into ad_events (ad_id, user_key, kind)
  values (p_ad_id, p_user_key, p_kind)
  on conflict do nothing;
end;
$$;

revoke all on function public.ad_event_log(uuid, text, text) from public;
grant execute on function public.ad_event_log(uuid, text, text) to anon, authenticated;

-- ------------------------------------------------------------
-- 4. What the advertiser is shown
-- ------------------------------------------------------------
-- Taps and arrivals side by side. "Twelve asked for directions, five
-- walked in" is a different kind of number to sell than impressions.
create or replace function public.ad_stats(p_ad_id uuid, p_days int default 30)
returns table (day date, directions bigint, arrivals bigint)
language sql security definer set search_path = public as $$
  select
    e.day,
    count(*) filter (where e.kind = 'directions') as directions,
    count(*) filter (where e.kind = 'arrival')    as arrivals
  from ad_events e
  where e.ad_id = p_ad_id
    and e.day >= current_date - p_days
  group by e.day
  order by e.day desc;
$$;

revoke all on function public.ad_stats(uuid, int) from public;
grant execute on function public.ad_stats(uuid, int) to authenticated;
