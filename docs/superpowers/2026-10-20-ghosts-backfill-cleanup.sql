-- Clean up the ghosts backfill outside Palma.
-- 050 tagged every citypack's 'headline' places; that category means
-- "ghost story" only in Palma. Expect ~49 rows.
update public.hotspots
   set themes = array_remove(themes, 'ghosts')
 where citypack_id <> 'a1b2c3d4-0000-0000-0000-000000000001'
   and themes @> array['ghosts'];

-- Should be 15 (Palma) and 0 (everywhere else).
select count(*) filter (where citypack_id = 'a1b2c3d4-0000-0000-0000-000000000001') as palma,
       count(*) filter (where citypack_id <> 'a1b2c3d4-0000-0000-0000-000000000001') as elsewhere
  from public.hotspots where themes @> array['ghosts'];
