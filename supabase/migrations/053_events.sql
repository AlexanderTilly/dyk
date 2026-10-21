-- 053_events.sql — events on the Nearby map, alongside the existing ads.
-- Idempotent. Run in Supabase → SQL Editor as the default (postgres) user.
--
-- Why this rides on internal_ads instead of a new table. An event and an ad
-- are the same shape already: a title, a subtitle, a picture, a point on the
-- map, a radius, a link. The admin page, the storage bucket, the loader and
-- the read policy all exist. A second table would duplicate every one of them
-- to buy a distinction that one column expresses.
--
-- What an event has that an ad does not is a time: it starts, and it ends,
-- and after it ends it must stop being shown. That is the whole delta.

begin;

alter table public.internal_ads
  add column if not exists kind text not null default 'ad';

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'internal_ads_kind_check'
  ) then
    alter table public.internal_ads
      add constraint internal_ads_kind_check check (kind in ('ad', 'event'));
  end if;
end $$;

-- Nullable on purpose. An event with no end date is legitimate (a permanent
-- installation, an open-ended exhibition), and the app treats a null end as
-- "still on" rather than hiding it.
alter table public.internal_ads
  add column if not exists starts_at timestamptz;

alter table public.internal_ads
  add column if not exists ends_at timestamptz;

-- The app's only query is "which events are still on", so index the pair it
-- filters by rather than each column alone.
create index if not exists internal_ads_kind_ends_idx
  on public.internal_ads (kind, ends_at);

commit;

-- Check after running:
--   select kind, count(*) from public.internal_ads group by kind;
--   -- expect every existing row to read 'ad'; events appear once admin adds them.
