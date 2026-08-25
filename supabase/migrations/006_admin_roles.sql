-- DYK admin security: roles + write policies
-- Run in Supabase SQL Editor

-- ============================================================
-- ROLES
-- ============================================================
create table public.user_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('super_admin', 'admin', 'business_owner')),
  created_at timestamptz not null default now()
);
alter table public.user_roles enable row level security;

-- A user may read their own role row
create policy "read_own_role" on public.user_roles
  for select using (user_id = auth.uid());

-- Helpers (security definer so they can read user_roles under RLS)
create or replace function public.is_admin()
returns boolean language sql security definer stable as $$
  select exists (
    select 1 from public.user_roles
    where user_id = auth.uid() and role in ('super_admin', 'admin')
  );
$$;

create or replace function public.is_super_admin()
returns boolean language sql security definer stable as $$
  select exists (
    select 1 from public.user_roles
    where user_id = auth.uid() and role = 'super_admin'
  );
$$;

-- ============================================================
-- ADMIN WRITE/READ ACCESS TO CONTENT
-- (these ADD to the existing public read policies)
-- ============================================================
create policy "admin_all_citypacks" on public.citypacks
  for all using (public.is_admin()) with check (public.is_admin());

create policy "admin_all_hotspots" on public.hotspots
  for all using (public.is_admin()) with check (public.is_admin());

create policy "admin_all_media" on public.hotspot_media
  for all using (public.is_admin()) with check (public.is_admin());

create policy "admin_all_deals" on public.hot_deals
  for all using (public.is_admin()) with check (public.is_admin());

-- Super admins can manage roles (grant/revoke)
create policy "super_admin_manage_roles" on public.user_roles
  for all using (public.is_super_admin()) with check (public.is_super_admin());

-- ============================================================
-- STORAGE: admins can upload/delete audio + images
-- ============================================================
create policy "admin_storage_all" on storage.objects
  for all
  using (bucket_id in ('hotspot-audio', 'hotspot-images') and public.is_admin())
  with check (bucket_id in ('hotspot-audio', 'hotspot-images') and public.is_admin());
