-- DYK: "Did You Know?" facts per hotspot
-- Run in Supabase SQL Editor

create table public.hotspot_facts (
  id uuid primary key default gen_random_uuid(),
  hotspot_id uuid not null references public.hotspots(id) on delete cascade,
  text text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create index hotspot_facts_hotspot_id_idx on public.hotspot_facts(hotspot_id);

alter table public.hotspot_facts enable row level security;

-- Facts are public content (shown on the hotspot detail page)
create policy "facts_public_read" on public.hotspot_facts
  for select using (true);

-- Admins manage facts
create policy "facts_admin_all" on public.hotspot_facts
  for all using (public.is_admin()) with check (public.is_admin());
