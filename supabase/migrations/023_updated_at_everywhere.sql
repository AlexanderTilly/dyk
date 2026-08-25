-- "Last edited" on all admin-managed tables (hotspots got it in 022).
-- Reuses the set_updated_at() trigger function from migration 022.

alter table public.citypacks    add column if not exists updated_at timestamptz not null default now();
alter table public.hot_deals    add column if not exists updated_at timestamptz not null default now();
alter table public.internal_ads add column if not exists updated_at timestamptz not null default now();
alter table public.tours        add column if not exists updated_at timestamptz not null default now();
alter table public.tour_stops   add column if not exists updated_at timestamptz not null default now();

drop trigger if exists citypacks_set_updated_at on public.citypacks;
create trigger citypacks_set_updated_at
  before update on public.citypacks
  for each row execute function public.set_updated_at();

drop trigger if exists hot_deals_set_updated_at on public.hot_deals;
create trigger hot_deals_set_updated_at
  before update on public.hot_deals
  for each row execute function public.set_updated_at();

drop trigger if exists internal_ads_set_updated_at on public.internal_ads;
create trigger internal_ads_set_updated_at
  before update on public.internal_ads
  for each row execute function public.set_updated_at();

drop trigger if exists tours_set_updated_at on public.tours;
create trigger tours_set_updated_at
  before update on public.tours
  for each row execute function public.set_updated_at();

drop trigger if exists tour_stops_set_updated_at on public.tour_stops;
create trigger tour_stops_set_updated_at
  before update on public.tour_stops
  for each row execute function public.set_updated_at();
