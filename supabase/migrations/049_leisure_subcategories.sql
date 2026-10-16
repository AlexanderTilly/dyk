-- 049_leisure_subcategories.sql — give Leisure subcategories a tourist can use.
-- Idempotent. Run in Supabase → SQL Editor as the default (postgres) user.
--
-- Leisure is a negation: it says "not history" and promises nothing. Standing
-- on a street wanting somewhere to eat, that is not a filter. The app now
-- offers restaurants / bars / museums / natural_spaces / shops under it, and
-- this brings the stored values into line with that list.
--
-- Two changes, and one deliberate non-change:
--
--   art (9 rows)        -> museums     the key should mean what it says
--   leisure (42 rows)   -> null        it meant nothing the filter can offer
--   natural_spaces      unchanged      already right; only its label moved
--
-- Clearing 'leisure' rather than guessing is the point. Those 42 are
-- restaurants, bars and shops in unknown proportion, and a wrong guess is
-- worse than none: the app shows untagged places under "Other", so they stay
-- on the map and findable while Jose sorts them out. A bad guess would hide
-- a bar inside Restaurants with nothing to show anything was wrong.

begin;

update public.hotspots
   set subcategory = 'museums'
 where category = 'otium'
   and subcategory = 'art';

update public.hotspots
   set subcategory = null
 where category = 'otium'
   and subcategory = 'leisure';

commit;

-- What is left to do by hand, after this runs:
--   select count(*) from public.hotspots
--    where category = 'otium' and subcategory is null;
-- Those are the ones showing as "Other" in the app until someone picks for
-- them. Everything still appears on the map; only the narrow filters miss it.
