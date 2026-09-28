-- 048_michelle_support_writer.sql — Michelle's write role: exactly one thing.
-- Idempotent: safe to re-run. Run in Supabase → SQL Editor as the default (postgres) user.
-- Replace REPLACE_ME with a long random password before running.
--
-- What this grants: INSERT on support_messages, and only when the row is
-- shaped author='michelle', author_user_id is null. No SELECT, no UPDATE,
-- no DELETE, no other table, no other schema. This role cannot even read
-- back the row it just inserted — every read Michelle does still goes
-- through the existing michelle_ro role (db/michelle_role.sql).
--
-- Applied by the owner only, never automatically. Depends on migration 045
-- (creates support_messages). After applying, set MICHELLE_PASSIM_WRITE_DB_URL
-- in the michelle repo's .env to this role's session-pooler connection string.

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'michelle_rw') then
    create role michelle_rw
      login password 'REPLACE_ME'
      nosuperuser nocreatedb nocreaterole noinherit;
  end if;
end $$;

alter role michelle_rw set statement_timeout = '8s';

grant usage on schema public to michelle_rw;
grant insert on public.support_messages to michelle_rw;

drop policy if exists michelle_rw_insert on public.support_messages;
create policy michelle_rw_insert on public.support_messages
  for insert to michelle_rw
  with check (author = 'michelle' and author_user_id is null);

-- Restrictive, on top of the permissive policy above: permissive policies on
-- this table are OR'ed together, and support_messages_admin_all (045) applies
-- to PUBLIC (no `to` clause) whenever is_admin() is true. is_admin() reads
-- auth.uid(), which any login role can influence by setting its own session's
-- request.jwt.claims. Without this restrictive policy, a compromised
-- michelle_rw credential combined with a known admin id could insert a row
-- shaped as 'staff' or 'customer'. A restrictive policy is AND'ed with every
-- permissive policy's result and cannot be widened by anything else on this
-- table — it holds even if is_admin() were ever satisfied.
drop policy if exists michelle_rw_restrict on public.support_messages;
create policy michelle_rw_restrict on public.support_messages
  as restrictive for insert to michelle_rw
  with check (author = 'michelle' and author_user_id is null);

-- Verify (run separately, should return one row with rolsuper = false):
-- select rolname, rolsuper, rolcreaterole, rolcreatedb from pg_roles where rolname = 'michelle_rw';
