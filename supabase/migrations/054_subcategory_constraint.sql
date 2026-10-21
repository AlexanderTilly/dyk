-- 054_subcategory_constraint.sql — let the database accept the subcategories
-- the app and the admin actually offer.
-- Idempotent. Run in Supabase → SQL Editor as the default (postgres) user.
--
-- The bug this fixes, seen in admin on 2026-10-21: picking "Shop" on a
-- hotspot fails with
--   new row for relation "hotspots" violates check constraint
--   "hotspots_subcategory_check"
--
-- Why. 015 created the column with a CHECK listing the subcategories of the
-- time: building, work_of_art, historical_figure, leisure, art,
-- natural_spaces. On 2026-10-16 Leisure's list was rewritten to
-- restaurants / bars / museums / natural_spaces / shops, and migration 049
-- was written to move the data across — but 049 only ever touched rows. It
-- left the constraint alone, so the database still refuses every new value.
-- Production confirms it: 40 rows still read 'leisure' and 9 read 'art', so
-- 049 was never run either. This migration does both jobs and supersedes it;
-- running 049 afterwards is a harmless no-op.
--
-- Order matters here. The constraint has to go first, because 'museums' is
-- not a value the old one permits — updating the data while it stood would
-- fail on exactly the rows we are trying to fix.

begin;

-- 1. Out with the old list.
alter table public.hotspots
  drop constraint if exists hotspots_subcategory_check;

-- 2. Bring the stored values into line (what 049 intended).
--    art -> museums: the key should mean what it says.
update public.hotspots
   set subcategory = 'museums'
 where category = 'otium'
   and subcategory = 'art';

--    leisure -> null: it meant "not history" and promised nothing, which is
--    not a filter anyone can use. Clearing rather than guessing is the point:
--    those rows are restaurants, bars and shops in unknown proportion, and
--    the app shows untagged places under "Other", so they stay on the map and
--    findable while someone sorts them out. A wrong guess would hide a bar
--    inside Restaurants with nothing to show anything was wrong.
update public.hotspots
   set subcategory = null
 where category = 'otium'
   and subcategory = 'leisure';

-- 3. In with the list the app and admin agree on. Keys live in
--    palma_app/lib/models/subcategories.dart and
--    dyk-admin/src/subcategories.ts; this is the third copy and the only one
--    that can reject a write, so it has to match them exactly.
--    null stays legal — it is how a place says "not classified yet".
alter table public.hotspots
  add constraint hotspots_subcategory_check check (
    subcategory is null or subcategory in (
      -- history
      'building', 'work_of_art', 'historical_figure',
      -- otium
      'restaurants', 'bars', 'museums', 'natural_spaces', 'shops'
    )
  );

commit;

-- Check after running:
--   select subcategory, count(*) from public.hotspots group by subcategory;
--   -- expect no 'leisure' and no 'art'; 9 more under 'museums'; 40 more null.
-- Then pick "Shop" on a hotspot in admin and save — it should go through.
