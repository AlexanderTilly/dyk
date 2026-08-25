-- DYK: GPS-targeted internal ads (first-party promos shown near a location)
-- Run in Supabase SQL Editor

create table public.internal_ads (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  subtitle text,
  icon_url text,
  image_url text,
  target_lat double precision not null,
  target_lng double precision not null,
  radius_km double precision not null default 25,
  link_url text,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

alter table public.internal_ads enable row level security;

create policy "ads_public_read" on public.internal_ads
  for select using (is_active = true);

create policy "ads_admin_all" on public.internal_ads
  for all using (public.is_admin()) with check (public.is_admin());

-- First ad: Tapas Route, targeted at Palma de Mallorca (~25 km)
insert into public.internal_ads
  (title, subtitle, icon_url, image_url, target_lat, target_lng, radius_km, is_active, sort_order)
values (
  'Tapas Route',
  'Explore Palma through food, stories and hidden local gems.',
  'https://jqykkyhoxpykhixwgwyw.supabase.co/storage/v1/object/public/hotspot-images/ads/tapastour_icon.png',
  'https://jqykkyhoxpykhixwgwyw.supabase.co/storage/v1/object/public/hotspot-images/ads/tapastour_back.png',
  39.5696, 2.6502, 25, true, 0
);
