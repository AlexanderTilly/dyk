-- ============================================================
-- Did You Know! (DYK) — Full database setup
-- Paste this entire file into Supabase SQL Editor and click Run
-- ============================================================

-- ============================================================
-- TABLES
-- ============================================================

create table public.citypacks (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  city text not null,
  country text not null,
  description text,
  price_sek integer not null default 49,
  is_published boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.hotspots (
  id uuid primary key default gen_random_uuid(),
  citypack_id uuid not null references public.citypacks(id) on delete cascade,
  slug text not null unique,
  name text not null,
  subtitle text,
  description text,
  lat double precision not null,
  lng double precision not null,
  radius_meters integer not null default 50,
  year integer,
  is_free boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table public.hotspot_media (
  id uuid primary key default gen_random_uuid(),
  hotspot_id uuid not null references public.hotspots(id) on delete cascade,
  media_type text not null check (media_type in ('audio', 'image')),
  storage_path text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table public.hot_deals (
  id uuid primary key default gen_random_uuid(),
  citypack_id uuid not null references public.citypacks(id) on delete cascade,
  business_name text not null,
  offer_text text not null,
  lat double precision not null,
  lng double precision not null,
  radius_meters integer not null default 80,
  is_active boolean not null default true,
  valid_from timestamptz,
  valid_to timestamptz,
  created_at timestamptz not null default now()
);

create table public.user_purchases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  citypack_id uuid not null references public.citypacks(id) on delete cascade,
  purchased_at timestamptz not null default now(),
  platform text not null check (platform in ('ios', 'android', 'web')),
  unique(user_id, citypack_id)
);

create index hotspots_citypack_id_idx on public.hotspots(citypack_id);
create index hot_deals_citypack_id_idx on public.hot_deals(citypack_id);
create index user_purchases_user_id_idx on public.user_purchases(user_id);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

alter table public.citypacks enable row level security;
alter table public.hotspots enable row level security;
alter table public.hotspot_media enable row level security;
alter table public.hot_deals enable row level security;
alter table public.user_purchases enable row level security;

create or replace function public.has_purchased(p_citypack_id uuid)
returns boolean language sql security definer stable as $$
  select exists (
    select 1 from public.user_purchases
    where user_id = auth.uid() and citypack_id = p_citypack_id
  );
$$;

create policy "citypacks_public_read" on public.citypacks
  for select using (is_published = true);

create policy "hotspots_read" on public.hotspots
  for select using (is_free = true or public.has_purchased(citypack_id));

create policy "hotspot_media_read" on public.hotspot_media
  for select using (
    exists (
      select 1 from public.hotspots h
      where h.id = hotspot_id
      and (h.is_free = true or public.has_purchased(h.citypack_id))
    )
  );

create policy "hot_deals_free_users" on public.hot_deals
  for select using (
    is_active = true
    and (valid_from is null or valid_from <= now())
    and (valid_to is null or valid_to >= now())
    and not public.has_purchased(citypack_id)
  );

create policy "user_purchases_own_read" on public.user_purchases
  for select using (user_id = auth.uid());

create policy "user_purchases_own_insert" on public.user_purchases
  for insert with check (user_id = auth.uid());

-- ============================================================
-- STORAGE BUCKETS
-- ============================================================

insert into storage.buckets (id, name, public) values ('hotspot-audio', 'hotspot-audio', false);
insert into storage.buckets (id, name, public) values ('hotspot-images', 'hotspot-images', true);

create policy "images_public_read" on storage.objects
  for select using (bucket_id = 'hotspot-images');

create policy "audio_auth_read" on storage.objects
  for select using (bucket_id = 'hotspot-audio' and auth.role() = 'authenticated');

create policy "admin_upload_audio" on storage.objects
  for insert with check (bucket_id = 'hotspot-audio' and auth.role() = 'service_role');

create policy "admin_upload_images" on storage.objects
  for insert with check (bucket_id = 'hotspot-images' and auth.role() = 'service_role');

-- ============================================================
-- SEED DATA — Palma de Mallorca
-- ============================================================

insert into public.citypacks (id, name, city, country, description, price_sek, is_published)
values (
  'a1b2c3d4-0000-0000-0000-000000000001',
  'Palma de Mallorca',
  'Palma',
  'Spain',
  'Explore Palma''s historic old town with audio guides and local tips.',
  49,
  true
);

insert into public.hotspots (citypack_id, slug, name, subtitle, description, lat, lng, radius_meters, year, is_free, sort_order)
values
(
  'a1b2c3d4-0000-0000-0000-000000000001',
  'catedral',
  'Catedral de Mallorca',
  'La Seu • Founded 1229',
  'The cathedral was built on the orders of King Jaime I after he defeated the Moors in 1229. It took over 400 years to complete this Gothic masterpiece by the waterfront.',
  39.5671, 2.6498, 60, 1229, true, 1
),
(
  'a1b2c3d4-0000-0000-0000-000000000001',
  'placa_major',
  'Plaça Major',
  'Heart of the city • 19th century',
  'Plaça Major is Palma''s central square, surrounded by elegant arcades and street cafés. It has been a meeting place for trade, politics and culture for over 200 years.',
  39.5697, 2.6500, 50, 1803, true, 2
),
(
  'a1b2c3d4-0000-0000-0000-000000000001',
  'placa_cort',
  'Plaça de Cort',
  'Town Hall Square • 15th century',
  'Plaça de Cort is home to Palma''s 17th-century town hall and the famous ancient olive tree — one of the most photographed sights in the city.',
  39.5694, 2.6503, 40, 1400, false, 3
);

insert into public.hot_deals (citypack_id, business_name, offer_text, lat, lng, radius_meters, is_active)
values (
  'a1b2c3d4-0000-0000-0000-000000000001',
  'Restaurang La Bóveda',
  '15% off lunch — show this notification',
  39.5675, 2.6495, 80, true
);
