-- Explicit creator flag on tours: keeps DYK tours and creator tours separated
-- in admin, and is the hook for creator-role permissions later.
alter table public.tours
  add column if not exists is_creator boolean not null default false;

-- Backfill: anything that already has a creator name is a creator tour.
update public.tours
  set is_creator = true
  where coalesce(creator_name, '') <> '';
