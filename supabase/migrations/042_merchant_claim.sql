-- Linking a merchant to their login without copying UUIDs around.
-- The admin types the business's email on the merchant row; the first time
-- someone signs in with exactly that email, their account claims the row.

create or replace function public.merchant_claim()
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_email text;
  v_id uuid;
begin
  select email into v_email from auth.users where id = auth.uid();
  if v_email is null then return null; end if;

  -- Already linked? Just report it.
  select id into v_id from merchants where owner_user_id = auth.uid();
  if found then return v_id; end if;

  -- Claim an unclaimed merchant whose contact email matches this account.
  update merchants
    set owner_user_id = auth.uid()
    where owner_user_id is null
      and lower(contact_email) = lower(v_email)
    returning id into v_id;

  return v_id;
end;
$$;
revoke all on function public.merchant_claim() from public;
grant execute on function public.merchant_claim() to authenticated;

-- Admins need to see who exists in order to link accounts by hand as well.
-- (profiles is already admin-readable; nothing new is exposed here.)

-- Admin-side manual link, so a merchant can also be attached to an account
-- whose email differs from the business contact address.
create or replace function public.merchant_link_user(
  p_merchant_id uuid, p_email text
) returns void
language plpgsql security definer set search_path = public as $$
declare v_user uuid;
begin
  if not public.is_admin() then raise exception 'not an admin'; end if;
  select id into v_user from auth.users where lower(email) = lower(trim(p_email));
  if not found then
    raise exception 'no account exists with that email yet — ask them to sign up first';
  end if;
  update merchants set owner_user_id = v_user where id = p_merchant_id;
end;
$$;
revoke all on function public.merchant_link_user(uuid, text) from public;
grant execute on function public.merchant_link_user(uuid, text) to authenticated;
