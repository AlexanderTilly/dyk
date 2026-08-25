-- DYK: user profiles for admin user-management
-- Run in Supabase SQL Editor

create table public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text,
  display_name text,
  platform text,            -- 'android' | 'ios' | 'web'
  device_model text,        -- e.g. "Samsung Galaxy S21"
  app_version text,
  registered_city text,     -- nearest city / coordinates at signup
  status text not null default 'active' check (status in ('active', 'paused')),
  created_at timestamptz not null default now(),
  last_seen timestamptz
);

alter table public.profiles enable row level security;

-- A user can read and update their own profile
create policy "own_profile_read" on public.profiles
  for select using (user_id = auth.uid());
create policy "own_profile_upsert" on public.profiles
  for insert with check (user_id = auth.uid());
create policy "own_profile_update" on public.profiles
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Admins can read every profile and change status (pause/reactivate)
create policy "admin_profiles_read" on public.profiles
  for select using (public.is_admin());
create policy "admin_profiles_update" on public.profiles
  for update using (public.is_admin()) with check (public.is_admin());

-- Auto-create a profile row whenever a new auth user signs up, so the
-- admin sees them even before the app fills in device details.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (user_id, email, display_name)
  values (new.id, new.email, new.raw_user_meta_data->>'display_name')
  on conflict (user_id) do nothing;
  return new;
end; $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Backfill profiles for any users who already signed up
insert into public.profiles (user_id, email, display_name)
select id, email, raw_user_meta_data->>'display_name'
from auth.users
on conflict (user_id) do nothing;
