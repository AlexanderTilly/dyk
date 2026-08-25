-- Fas 2: content translations (es / ca / de). English stays the master copy
-- in the main tables; translations overlay it in the app, falling back to
-- English wherever a translation is missing.

create table if not exists public.hotspot_translations (
  hotspot_id uuid not null references public.hotspots(id) on delete cascade,
  lang text not null check (lang in ('es', 'ca', 'de')),
  name text,
  subtitle text,
  description text,
  facts jsonb, -- array of strings, same order as hotspot_facts
  updated_at timestamptz not null default now(),
  primary key (hotspot_id, lang)
);

create table if not exists public.tour_translations (
  tour_id uuid not null references public.tours(id) on delete cascade,
  lang text not null check (lang in ('es', 'ca', 'de')),
  title text,
  subtitle text,
  description text,
  updated_at timestamptz not null default now(),
  primary key (tour_id, lang)
);

drop trigger if exists hotspot_translations_set_updated_at on public.hotspot_translations;
create trigger hotspot_translations_set_updated_at
  before update on public.hotspot_translations
  for each row execute function public.set_updated_at();

drop trigger if exists tour_translations_set_updated_at on public.tour_translations;
create trigger tour_translations_set_updated_at
  before update on public.tour_translations
  for each row execute function public.set_updated_at();

alter table public.hotspot_translations enable row level security;
alter table public.tour_translations enable row level security;

-- Everyone may read (the app needs them); only admins may write.
drop policy if exists hotspot_translations_read on public.hotspot_translations;
create policy hotspot_translations_read on public.hotspot_translations
  for select to anon, authenticated using (true);

drop policy if exists hotspot_translations_admin_write on public.hotspot_translations;
create policy hotspot_translations_admin_write on public.hotspot_translations
  for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists tour_translations_read on public.tour_translations;
create policy tour_translations_read on public.tour_translations
  for select to anon, authenticated using (true);

drop policy if exists tour_translations_admin_write on public.tour_translations;
create policy tour_translations_admin_write on public.tour_translations
  for all using (public.is_admin()) with check (public.is_admin());
