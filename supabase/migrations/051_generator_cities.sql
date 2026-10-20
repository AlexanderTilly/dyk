-- 051_generator_cities.sql — which cities may offer the tour generator.
-- Idempotent. Run in Supabase → SQL Editor as the default (postgres) user.
--
-- The generator cuts a walkable round out of a city's narrated places. A city
-- whose places have no narration would still produce a handsome map and a
-- correct route, and the tourist would walk it in headphones hearing nothing.
-- That is worse than no feature, so a city only qualifies once enough of its
-- places have English narration (English is the master language; the other
-- three are translations of it).
--
-- The threshold (20) lives here and only here. The app does not repeat it: it
-- asks this view which cities qualify.
--
-- Counts DISTINCT hotspots, not audio rows, because a place can carry several
-- audio rows. Only published citypacks are listed.
--
-- Privileges. hotspot_media and hotspots are RLS-protected (a row is readable
-- only if the place is free or purchased), so a caller's own rights would
-- undercount. The view is therefore stated explicitly as security_invoker = false:
-- it runs with its owner's rights, which bypass RLS, and reports the true
-- count. It exposes only a citypack id and a number, nothing per-place. The
-- explicit grant is what lets the anonymous app read it at all.
--
-- Until this has been run the app cannot read the view, treats that as "no
-- cities" and hides the generator (fails closed).

begin;

-- Dropped first: create or replace cannot change output columns (42P16).
drop view if exists public.generator_cities;

create view public.generator_cities
  with (security_invoker = false) as
with threshold as (select 20 as min_narrated)
select h.citypack_id,
       count(distinct h.id)::int as narrated_count
  from public.hotspots h
  join public.hotspot_media m on m.hotspot_id = h.id
  join public.citypacks c on c.id = h.citypack_id
 where m.media_type = 'audio'
   and m.lang = 'en'
   and c.is_published = true
 group by h.citypack_id
having count(distinct h.id) >= (select min_narrated from threshold);

grant select on public.generator_cities to anon, authenticated;

commit;

-- Check after running (expect Palma only; Madrid, Zürich, Barcelona are silent):
--   select * from public.generator_cities;
