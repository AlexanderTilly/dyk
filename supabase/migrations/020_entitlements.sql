-- Monetisation Phase A: per-city unlock + premium (free unlock now; real IAP later).

-- Premium flag on the user's profile.
alter table public.profiles
  add column if not exists is_premium boolean not null default false;

-- Unlock a single city for the signed-in user (free now).
create or replace function public.unlock_city(p_citypack_id uuid)
returns void language plpgsql security definer
set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'Must be signed in to unlock';
  end if;
  insert into public.user_purchases (user_id, citypack_id, platform)
  values (auth.uid(), p_citypack_id, 'android')
  on conflict do nothing;
end;
$$;

-- Turn on premium for the signed-in user (free now).
create or replace function public.set_premium()
returns void language plpgsql security definer
set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'Must be signed in';
  end if;
  insert into public.profiles (user_id, is_premium)
  values (auth.uid(), true)
  on conflict (user_id) do update set is_premium = true;
end;
$$;

-- What the signed-in user owns: premium flag + purchased city ids.
create or replace function public.get_entitlements()
returns jsonb language sql security definer stable
set search_path = public as $$
  select jsonb_build_object(
    'is_premium',
      coalesce((select is_premium from public.profiles where user_id = auth.uid()), false),
    'cities',
      coalesce((
        select array_agg(citypack_id)
        from public.user_purchases
        where user_id = auth.uid() and citypack_id is not null
      ), array[]::uuid[])
  );
$$;

grant execute on function public.unlock_city(uuid) to authenticated;
grant execute on function public.set_premium() to authenticated;
grant execute on function public.get_entitlements() to anon, authenticated;
