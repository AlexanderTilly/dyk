-- Pickpocket activity reports — temporary crowd-sourced safety pins.
-- Reports auto-expire after 3 hours. Only authenticated users may report;
-- anyone (incl. guests) may view via the security-definer read function.

create table if not exists public.pickpocket_reports (
  id uuid primary key default gen_random_uuid(),
  lat double precision not null,
  lng double precision not null,
  description text,
  reporter_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '3 hours')
);

create index if not exists pickpocket_reports_expires_idx
  on public.pickpocket_reports (expires_at);

alter table public.pickpocket_reports enable row level security;
-- No direct table access; everything goes through the RPCs below.

-- Insert a report for the signed-in user (3h TTL).
create or replace function public.report_pickpocket(
  p_lat double precision,
  p_lng double precision,
  p_description text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Must be signed in to report';
  end if;
  insert into public.pickpocket_reports (lat, lng, description, reporter_id, expires_at)
  values (p_lat, p_lng, p_description, auth.uid(), now() + interval '3 hours');
end;
$$;

-- Return all non-expired reports.
create or replace function public.get_pickpocket_reports()
returns setof public.pickpocket_reports
language sql
security definer
stable
set search_path = public
as $$
  select * from public.pickpocket_reports
  where expires_at > now()
  order by created_at desc;
$$;

revoke all on function public.report_pickpocket(double precision, double precision, text) from public;
grant execute on function public.report_pickpocket(double precision, double precision, text) to authenticated;
grant execute on function public.get_pickpocket_reports() to anon, authenticated;
