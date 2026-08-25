-- Admin notes / to-dos per hotspot. Admin-internal only (never shown in the app).

create table if not exists public.hotspot_notes (
  id uuid primary key default gen_random_uuid(),
  hotspot_id uuid not null references public.hotspots(id) on delete cascade,
  text text not null,
  is_done boolean not null default false,
  done_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists hotspot_notes_hotspot_idx on public.hotspot_notes (hotspot_id);

drop trigger if exists hotspot_notes_set_updated_at on public.hotspot_notes;
create trigger hotspot_notes_set_updated_at
  before update on public.hotspot_notes
  for each row execute function public.set_updated_at();

alter table public.hotspot_notes enable row level security;

-- Only admins may read or write notes.
drop policy if exists hotspot_notes_admin_all on public.hotspot_notes;
create policy hotspot_notes_admin_all on public.hotspot_notes
  for all using (public.is_admin()) with check (public.is_admin());
