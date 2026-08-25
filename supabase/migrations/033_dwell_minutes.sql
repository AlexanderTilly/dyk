-- Suggested stay per stop (minutes). Used by the arrival "dwell" page and
-- the pacing nudge ("we need to move to make all stops today").
alter table public.tour_stops
  add column if not exists dwell_minutes int not null default 0;
