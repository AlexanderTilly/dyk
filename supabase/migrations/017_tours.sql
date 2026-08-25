-- Tours: reusable guided walking loops (History Walks, Tapas Route, ...).
-- Stops either link an existing hotspot OR carry their own venue content.
-- Route geometry is precomputed in admin; the app only renders it.

create table if not exists public.tours (
  id uuid primary key default gen_random_uuid(),
  citypack_id uuid not null references public.citypacks(id) on delete cascade,
  type text not null default 'history_walk'
    check (type in ('history_walk', 'food_drink', 'custom')),
  title text not null,
  subtitle text,
  description text,
  hero_image text,
  price_sek integer not null default 0,
  is_published boolean not null default false,
  distance_meters integer,
  est_minutes integer,
  route_geojson jsonb,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.tour_stops (
  id uuid primary key default gen_random_uuid(),
  tour_id uuid not null references public.tours(id) on delete cascade,
  order_index integer not null default 0,
  hotspot_id uuid references public.hotspots(id) on delete set null,
  title text,
  blurb text,
  lat double precision,
  lng double precision,
  image text,
  audio_path text,
  offer_text text,
  redeem_code text,
  arrival_radius_meters integer not null default 40,
  created_at timestamptz not null default now()
);

create table if not exists public.tour_progress (
  user_id uuid not null references auth.users(id) on delete cascade,
  tour_id uuid not null references public.tours(id) on delete cascade,
  stop_id uuid not null references public.tour_stops(id) on delete cascade,
  visited_at timestamptz not null default now(),
  primary key (user_id, stop_id)
);

-- Reuse user_purchases for ownership; add a tour_id alongside citypack_id.
alter table public.user_purchases
  add column if not exists tour_id uuid references public.tours(id) on delete cascade;

create index if not exists tours_citypack_idx on public.tours(citypack_id);
create index if not exists tour_stops_tour_idx on public.tour_stops(tour_id);
create index if not exists tour_progress_user_tour_idx on public.tour_progress(user_id, tour_id);

alter table public.tours enable row level security;
alter table public.tour_stops enable row level security;
alter table public.tour_progress enable row level security;

-- Public can read published tours and their stops.
drop policy if exists tours_read on public.tours;
create policy tours_read on public.tours
  for select using (is_published = true);

drop policy if exists tour_stops_read on public.tour_stops;
create policy tour_stops_read on public.tour_stops
  for select using (
    exists (select 1 from public.tours t
            where t.id = tour_stops.tour_id and t.is_published = true)
  );

-- Admins manage tours + stops (mirrors existing admin-role helper is_admin()).
drop policy if exists tours_admin on public.tours;
create policy tours_admin on public.tours
  for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists tour_stops_admin on public.tour_stops;
create policy tour_stops_admin on public.tour_stops
  for all using (public.is_admin()) with check (public.is_admin());

-- Users see only their own progress.
drop policy if exists tour_progress_own on public.tour_progress;
create policy tour_progress_own on public.tour_progress
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Has the signed-in user unlocked this tour?
create or replace function public.has_tour(p_tour_id uuid)
returns boolean language sql security definer stable
set search_path = public as $$
  select exists (
    select 1 from public.user_purchases
    where user_id = auth.uid() and tour_id = p_tour_id
  );
$$;

-- Unlock a tour for the signed-in user (free now; payment wired later).
create or replace function public.unlock_tour(p_tour_id uuid)
returns void language plpgsql security definer
set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'Must be signed in to unlock';
  end if;
  insert into public.user_purchases (user_id, tour_id, platform)
  values (auth.uid(), p_tour_id, 'android')
  on conflict do nothing;
end;
$$;

-- Record a stop check-in for the signed-in user.
create or replace function public.record_tour_visit(p_tour_id uuid, p_stop_id uuid)
returns void language plpgsql security definer
set search_path = public as $$
begin
  if auth.uid() is null then return; end if;
  insert into public.tour_progress (user_id, tour_id, stop_id)
  values (auth.uid(), p_tour_id, p_stop_id)
  on conflict (user_id, stop_id) do nothing;
end;
$$;

grant execute on function public.has_tour(uuid) to anon, authenticated;
grant execute on function public.unlock_tour(uuid) to authenticated;
grant execute on function public.record_tour_visit(uuid, uuid) to authenticated;
