-- Admin user deletion from the dashboard. Only super_admin/admin may call
-- it, and admins cannot delete other admins by accident.
create or replace function public.admin_delete_user(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.user_roles
    where user_id = auth.uid() and role in ('super_admin', 'admin')
  ) then
    raise exception 'not an admin';
  end if;
  if exists (select 1 from public.user_roles where user_id = p_user_id) then
    raise exception 'cannot delete an admin account';
  end if;
  delete from public.user_purchases where user_id = p_user_id;
  delete from public.tour_progress  where user_id = p_user_id;
  delete from public.profiles       where user_id = p_user_id;
  delete from auth.users            where id = p_user_id;
end;
$$;

revoke all on function public.admin_delete_user(uuid) from public;
grant execute on function public.admin_delete_user(uuid) to authenticated;
