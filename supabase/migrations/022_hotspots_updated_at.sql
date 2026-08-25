-- Track when each hotspot was last edited, so the admin can show a
-- "Last edited" column and sort/filter by it.

alter table public.hotspots
  add column if not exists updated_at timestamptz not null default now();

create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists hotspots_set_updated_at on public.hotspots;
create trigger hotspots_set_updated_at
  before update on public.hotspots
  for each row execute function public.set_updated_at();

-- Backfill: give existing rows a sensible starting value.
update public.hotspots set updated_at = coalesce(created_at, now())
 where updated_at is null;
