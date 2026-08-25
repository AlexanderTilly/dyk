-- Account deletion from inside the app (required by Google Play / App Store
-- when an app offers account creation). Deletes the auth user; profile and
-- user data follow via ON DELETE CASCADE foreign keys.

create or replace function public.delete_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  -- Rows without cascading FKs are cleaned up explicitly.
  delete from public.user_purchases where user_id = auth.uid();
  delete from public.tour_progress  where user_id = auth.uid();
  delete from public.profiles       where id = auth.uid();
  delete from auth.users            where id = auth.uid();
end;
$$;

revoke all on function public.delete_account() from public;
grant execute on function public.delete_account() to authenticated;
