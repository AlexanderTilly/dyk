-- 055_museums_theme.sql — tag the museums we already know about.
-- Idempotent. Run in Supabase → SQL Editor as the default (postgres) user.
--
-- `museums` becomes the ninth generator theme. Unlike the other eight it does
-- not need a model to find its places: a museum is already marked as one in
-- `subcategory`, so the tagging is a join rather than a judgement.
--
-- Why not let tag-themes do it. That function only writes rows whose `themes`
-- are empty, and five of the eight museums in Palma already carry other
-- themes — Can Morell is a palace, La Misericòrdia a ghost story. They would
-- have been skipped, and the theme would have launched missing most of its
-- content.
--
-- So this appends rather than replaces. A museum that is also a palace is
-- both, and the generator is happy to put it in either round.

begin;

update public.hotspots
   set themes = array_append(themes, 'museums')
 where subcategory = 'museums'
   and not themes @> array['museums'];

commit;

-- Check after running:
--   select count(*) from public.hotspots where 'museums' = any(themes);
--   -- expect 8 in Palma.
--
--   select name, subcategory, themes from public.hotspots
--    where 'museums' = any(themes) order by name;
--   -- the five that already had a theme should still have it, with museums
--   -- added beside it rather than in place of it.
