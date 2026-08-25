-- DYK: anonymous install tracking (guests who downloaded but didn't register)
-- Run in Supabase SQL Editor

create table public.app_installs (
  anon_id uuid primary key,           -- random id generated & stored on device
  platform text,                       -- 'android' | 'ios'
  device_model text,
  app_version text,
  country text,                        -- derived from device locale (no GPS)
  first_seen timestamptz not null default now(),
  last_seen timestamptz not null default now(),
  became_user boolean not null default false
);

alter table public.app_installs enable row level security;

-- Anonymous app can register/refresh its own install row
create policy "anon_insert_install" on public.app_installs
  for insert with check (true);
create policy "anon_update_install" on public.app_installs
  for update using (true) with check (true);

-- Admins can read all installs
create policy "admin_read_installs" on public.app_installs
  for select using (public.is_admin());
