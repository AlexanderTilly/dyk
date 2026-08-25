-- Curation flags for the Tours tab sections: "Trending now" and
-- "Did You Know picks" are hand-picked in admin (no fake stats).
alter table public.tours
  add column if not exists is_trending boolean not null default false,
  add column if not exists is_pick boolean not null default false;
