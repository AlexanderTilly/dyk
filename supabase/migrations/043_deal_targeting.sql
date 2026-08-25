-- Deal targeting: who gets the push, and when. The merchant picks segments;
-- the matching happens on the device and in aggregate on the server, so a
-- business never sees an individual explorer.

alter table public.hot_deals
  -- "They have walked at least X steps today, so they must be thirsty."
  add column min_steps_today int not null default 0,
  -- 'any' | 'exclude' (leave people on a guided tour alone) | 'only'
  add column target_on_tour text not null default 'exclude'
    check (target_on_tour in ('any', 'exclude', 'only')),
  -- Weekdays it may fire (0 = Sunday … 6 = Saturday). Empty = every day.
  add column active_days int[] not null default '{}',
  -- Local hour window, e.g. 16–18 for happy hour. 0–24 = all day.
  add column active_hour_from int not null default 0,
  add column active_hour_to int not null default 24,
  -- 'any' | 'new' (arrived in the city within the last 24 h)
  add column target_arrival text not null default 'any'
    check (target_arrival in ('any', 'new')),
  -- Only explorers who follow this interest ('history' | 'otium' | 'headline').
  add column target_interest text;

-- Live audience: how many explorers are near this spot right now, optionally
-- filtered by how far they have walked today. Counts only — no identities,
-- no coordinates, and it deliberately reports "few" below a floor so a
-- merchant can never single anyone out.
alter table public.live_sessions add column steps_today int not null default 0;

create or replace function public.record_presence(
  p_session_id uuid, p_user_id uuid, p_label text, p_is_user boolean,
  p_lat double precision, p_lng double precision,
  p_status text, p_status_detail text, p_steps int
) returns void
language plpgsql security definer set search_path = public as $$
begin
  insert into public.live_sessions
    (session_id, user_id, display_label, is_user, lat, lng, status,
     status_detail, steps_today, updated_at)
  values
    (p_session_id, p_user_id, p_label, p_is_user, p_lat, p_lng, p_status,
     p_status_detail, coalesce(p_steps, 0), now())
  on conflict (session_id) do update set
    user_id = excluded.user_id,
    display_label = excluded.display_label,
    is_user = excluded.is_user,
    lat = excluded.lat,
    lng = excluded.lng,
    status = excluded.status,
    status_detail = excluded.status_detail,
    steps_today = excluded.steps_today,
    updated_at = now();
end; $$;
grant execute on function public.record_presence(
  uuid, uuid, text, boolean, double precision, double precision, text, text, int
) to anon, authenticated;

create or replace function public.deal_audience(
  p_lat double precision, p_lng double precision,
  p_radius_m int, p_min_steps int default 0
) returns int
language sql security definer stable set search_path = public as $$
  select count(*)::int
  from live_sessions s
  where s.updated_at > now() - interval '10 minutes'
    and s.steps_today >= coalesce(p_min_steps, 0)
    and s.lat is not null and s.lng is not null
    -- Rough metres-per-degree box first, then a circular check.
    and abs(s.lat - p_lat) < (p_radius_m / 111000.0) * 1.5
    and 6371000 * acos(least(1, greatest(-1,
          sin(radians(p_lat)) * sin(radians(s.lat)) +
          cos(radians(p_lat)) * cos(radians(s.lat)) *
          cos(radians(s.lng) - radians(p_lng))
        ))) <= p_radius_m;
$$;
grant execute on function public.deal_audience(
  double precision, double precision, int, int
) to authenticated;
