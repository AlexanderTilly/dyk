-- DYK: add Otium main category + subcategories to hotspots
-- Run in Supabase SQL Editor

-- Allow the new main category 'otium'
alter table public.hotspots drop constraint if exists hotspots_category_check;
alter table public.hotspots add constraint hotspots_category_check
  check (category in ('history', 'otium', 'funfact', 'headline'));

-- Subcategory (drives the map pin icon). Null for funfact/headline.
alter table public.hotspots add column if not exists subcategory text
  check (subcategory in (
    'building', 'work_of_art', 'historical_figure',
    'leisure', 'art', 'natural_spaces'
  ));
