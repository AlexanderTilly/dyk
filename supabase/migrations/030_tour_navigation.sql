-- Tour navigation upgrade: transport mode per tour + precomputed
-- turn-by-turn steps (generated once in admin, read-only in the app).

alter table public.tours
  add column if not exists transport_mode text not null default 'walking'
    check (transport_mode in ('walking', 'cycling', 'driving', 'boat')),
  add column if not exists route_steps jsonb;
