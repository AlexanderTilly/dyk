-- Tour start policy:
--   fixed  — the story requires the order; users are guided to stop 1 first
--   hop_on — closed loop; users can join at the nearest stop
alter table public.tours
  add column if not exists start_mode text not null default 'fixed'
    check (start_mode in ('fixed', 'hop_on'));
