-- Manual route tuning: via-points ([lng,lat] pairs) the route must pass
-- through. Survive re-generation so hand-tuning isn't lost.
alter table public.tours
  add column if not exists route_via jsonb;
