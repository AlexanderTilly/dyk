-- 048_michelle_support_writer.sql — Michelle's write role: exactly one thing.
-- Idempotent: safe to re-run. Run in Supabase → SQL Editor as the default (postgres) user.
-- Replace REPLACE_ME with a long random password before running.
--
-- What this grants: INSERT on support_messages, and only when the row is
-- shaped author='michelle', author_user_id is null. No SELECT, no UPDATE,
-- no DELETE, no other table, no other schema. This role cannot even read
-- back the row it just inserted — every read Michelle does still goes
-- through the existing michelle_ro role (db/michelle_role.sql).

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

-- Verify (run separately, should return one row with rolsuper = false):
-- select rolname, rolsuper, rolcreaterole, rolcreatedb from pg_roles where rolname = 'michelle_rw';
