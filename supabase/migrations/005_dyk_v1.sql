-- DYK v1: kategorier, inlösenkoder, user-tabeller
-- Kör i Supabase SQL Editor

-- Kategorier på hotspots
alter table public.hotspots add column category text not null default 'history'
  check (category in ('history', 'funfact', 'headline'));

-- Inlösenkod på deals
alter table public.hot_deals add column redeem_code text;

-- Användarens valda intressen
create table public.user_interests (
  user_id uuid not null references auth.users(id) on delete cascade,
  interest text not null check (interest in ('history', 'funfact', 'headline', 'hotdeal')),
  primary key (user_id, interest)
);
alter table public.user_interests enable row level security;
create policy "own_interests" on public.user_interests
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Sparade objekt
create table public.saved_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  item_type text not null check (item_type in ('hotspot', 'deal', 'citypack')),
  item_id uuid not null,
  created_at timestamptz not null default now(),
  unique(user_id, item_type, item_id)
);
alter table public.saved_items enable row level security;
create policy "own_saved" on public.saved_items
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Besökslogg
create table public.user_visits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  hotspot_id uuid not null references public.hotspots(id) on delete cascade,
  visited_at timestamptz not null default now()
);
alter table public.user_visits enable row level security;
create policy "own_visits" on public.user_visits
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Seed-uppdatering
update public.hotspots set category = 'history' where slug in ('catedral', 'placa_cort');
update public.hotspots set category = 'funfact' where slug = 'placa_major';
update public.hot_deals set redeem_code = 'PALMA25' where business_name = 'Restaurang La Bóveda';
