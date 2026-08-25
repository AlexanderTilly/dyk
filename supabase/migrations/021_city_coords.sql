-- Fas B: city center coordinates so the background service can detect
-- when a user arrives in a new city and fire a "Welcome to <city>" push.

alter table public.citypacks
  add column if not exists lat double precision,
  add column if not exists lng double precision,
  add column if not exists welcome_radius_km integer not null default 30;

-- Seed Palma's center so the flagship city works out of the box.
update public.citypacks
   set lat = 39.5696, lng = 2.6502
 where city ilike 'palma' and lat is null;
