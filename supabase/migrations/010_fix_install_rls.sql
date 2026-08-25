-- Fix: allow anonymous app installs to write their own row
-- Run in Supabase SQL Editor

drop policy if exists "anon_insert_install" on public.app_installs;
drop policy if exists "anon_update_install" on public.app_installs;

create policy "installs_insert" on public.app_installs
  for insert to anon, authenticated
  with check (true);

create policy "installs_update" on public.app_installs
  for update to anon, authenticated
  using (true) with check (true);
