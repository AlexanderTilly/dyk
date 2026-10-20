-- 050_tour_themes.sql — tag hotspots with the themes a generated tour is built from.
-- Idempotent. Run in Supabase → SQL Editor as the default (postgres) user.
--
-- A tour generator needs to ask "which places are about churches?" The keys
-- are the eight in palma_app/lib/models/themes.dart and
-- dyk-admin/src/themes.ts. ghosts is the existing headline category and is
-- backfilled below; the rest are filled in later, by hand or by a model.
--
-- Why an array column and not a join table. A place carries a handful of
-- short tags, and the only query is "which places have this theme". A text[]
-- answers that in one indexed lookup (the GIN index), and it keeps a hotspot
-- and its themes in one row, so writing a hotspot is still one write. A join
-- table would add a second table, a second set of policies, and a join on
-- every read, to buy flexibility this data does not need.
--
-- The tour columns are for generated tours: is_generated tells a tour the
-- generator made apart from one a person built, and generated_params keeps
-- the inputs it was made from so it can be regenerated or explained.

begin;

alter table public.hotspots
  add column if not exists themes text[] not null default '{}';

create index if not exists hotspots_themes_idx
  on public.hotspots using gin (themes);

alter table public.tours
  add column if not exists is_generated boolean not null default false;

alter table public.tours
  add column if not exists generated_params jsonb;

-- Backfill ghosts from the headline category, in Palma only. The guard makes
-- a re-run a no-op rather than rewriting rows that already carry the tag.
--
-- The citypack filter is not tidiness. 'headline' means a different thing in
-- each city's content: in Palma it is the fifteen ghost stories, elsewhere it
-- is simply a featured place. Without the filter this tagged 49 hotspots
-- across fourteen other cities, among them Athens' Syntagma Metro Station —
-- measured against production on 2026-10-20, after the first run.
update public.hotspots
   set themes = array_append(themes, 'ghosts')
 where category = 'headline'
   and citypack_id = 'a1b2c3d4-0000-0000-0000-000000000001'
   and not themes @> array['ghosts'];

-- Generated tours are deliberately unpublished so they stay out of the curated
-- list, but tours_read / tour_stops_read only expose published rows, so the
-- anonymous app could not read back a tour it just generated. They need their
-- own read path.
drop policy if exists tours_read_generated on public.tours;
create policy tours_read_generated on public.tours
  for select using (is_generated = true);

drop policy if exists tour_stops_read_generated on public.tour_stops;
create policy tour_stops_read_generated on public.tour_stops
  for select using (
    exists (select 1 from public.tours t
            where t.id = tour_stops.tour_id and t.is_generated = true)
  );

-- Who generated a tour lives in its own table, not on the tours row. Generated
-- tours are world-readable so an anonymous caller can walk one back, and RLS is
-- row-level: that makes EVERY column on the row public. Anything identifying
-- must therefore live elsewhere. (A column-level revoke on tours would not do:
-- the app reads tours with select(), i.e. *, which PostgREST expands to all
-- columns, so anon would get "permission denied" on every tour list.)
-- RLS on, no anon/authenticated policy: only the service role (the edge
-- function) writes, and admins read via is_admin().
create table if not exists public.generated_tour_installs (
  tour_id uuid primary key references public.tours(id) on delete cascade,
  install_id text not null,
  created_at timestamptz not null default now()
);

alter table public.generated_tour_installs enable row level security;

drop policy if exists generated_tour_installs_admin on public.generated_tour_installs;
create policy generated_tour_installs_admin on public.generated_tour_installs
  for select using (public.is_admin());

commit;

-- Check after running:
--   select count(*) from public.hotspots where 'ghosts' = any(themes);
