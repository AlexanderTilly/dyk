-- 056_generator_themes.sql — which themes a city has enough places for.
-- Idempotent. Run in Supabase → SQL Editor as the default (postgres) user.
--
-- The problem this solves, measured on 2026-11-05: "The sea & the harbour"
-- has two tagged places in Palma. selectPlaces needs three, so that position
-- on the wheel returned nothing from every start point and every distance —
-- the design's own anti-goal, "a pull that returns nothing", live in the app.
--
-- The threshold is five, not three. Three is the minimum a round can be built
-- from, and a theme sitting exactly on it can only ever produce the same
-- three places in the same order; the margin is what lets a second pull
-- differ from the first.
--
-- The count lives here rather than in the app so that tagging takes effect
-- without a release. Jose tags two more harbour places and the theme appears
-- on the wheel by itself.
--
-- WARNING: five is written in three places — here, dyk-admin/src/themes.ts
-- (THEME_MIN_PLACES) and lib/models/themes.dart. Nothing compares them at
-- runtime. Change one, change all three.
--
-- Like 051, this is security_invoker = false on purpose: the RLS on hotspots
-- hides unpurchased places from anon, and an invoker view would undercount
-- and hide themes from the very people the gate is meant to serve. It exposes
-- a citypack id, a theme key and a count — no places, no coordinates, nothing
-- a scraper could not already get from the published hotspot list.

begin;

drop view if exists public.generator_themes;

create view public.generator_themes
  with (security_invoker = false) as
with threshold as (select 5 as min_places)
select h.citypack_id,
       t.theme,
       count(*)::int as place_count
  from public.hotspots h
  cross join lateral unnest(h.themes) as t(theme)
  join public.citypacks c on c.id = h.citypack_id
 where c.is_published = true
 group by h.citypack_id, t.theme
having count(*) >= (select min_places from threshold);

grant select on public.generator_themes to anon, authenticated;

commit;

-- Check after running:
--   select theme, place_count from public.generator_themes
--    where citypack_id = 'a1b2c3d4-0000-0000-0000-000000000001'
--    order by place_count desc;
--
-- Expect eight rows for Palma and NO the_sea (it has 2). museums appears only
-- once 055 has run; without it that theme has no tagged places at all.
