-- DYK: live presence — one row per active device, updated every ~12s
-- Run in Supabase SQL Editor

create table public.live_sessions (
  session_id uuid primary key,        -- device anon id
  user_id uuid references auth.users(id) on delete set null,
  display_label text,                  -- name or 'Guest'
  is_user boolean not null default false,
  lat double precision,
  lng double precision,
  status text,                         -- 'exploring' | 'viewing' | 'near_deal' | 'idle'
  status_detail text,                  -- e.g. hotspot name
  updated_at timestamptz not null default now()
);

alter table public.live_sessions enable row level security;

-- Admins read all live sessions (Realtime respects RLS)
create policy "admin_read_live" on public.live_sessions
  for select using (public.is_admin());

-- Security-definer RPC the app calls to report presence (works for anon too)
create or replace function public.record_presence(
  p_session_id uuid, p_user_id uuid, p_label text, p_is_user boolean,
  p_lat double precision, p_lng double precision,
  p_status text, p_status_detail text
) returns void
language plpgsql security definer set search_path = public as $$
begin
  insert into public.live_sessions
    (session_id, user_id, display_label, is_user, lat, lng, status, status_detail, updated_at)
  values
    (p_session_id, p_user_id, p_label, p_is_user, p_lat, p_lng, p_status, p_status_detail, now())
  on conflict (session_id) do update set
    user_id = excluded.user_id,
    display_label = excluded.display_label,
    is_user = excluded.is_user,
    lat = excluded.lat,
    lng = excluded.lng,
    status = excluded.status,
    status_detail = excluded.status_detail,
    updated_at = now();
end; $$;

grant execute on function public.record_presence(uuid, uuid, text, boolean, double precision, double precision, text, text) to anon, authenticated;

-- Remove a session when the user stops exploring / closes
create or replace function public.end_presence(p_session_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  delete from public.live_sessions where session_id = p_session_id;
end; $$;

grant execute on function public.end_presence(uuid) to anon, authenticated;

-- Enable Realtime on the table so the admin map gets live pushes
alter publication supabase_realtime add table public.live_sessions;
