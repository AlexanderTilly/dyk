-- 052_saved_tours.sql — a person keeping a generated round.
-- Idempotent. Run in Supabase → SQL Editor as the default (postgres) user.
--
-- Anyone may pull the lever and walk the result: generate-tour is
-- unauthenticated and its tours are world-readable (migration 050). That means
-- nothing about a generated tour says whose it is. This table is the only
-- thing that makes a kept round YOURS, so its policies are the real boundary,
-- not a formality behind the app's own signed-in check.
--
-- Primary key on both ids: saving the same round twice hits the same row, so
-- the app can upsert and a repeat save is a no-op rather than an error. That
-- holds at the database, not just in Dart.
--
-- on delete cascade on both sides: deleting an account (delete_account) or a
-- tour must not strand rows pointing at nothing.
--
-- Policies are per command, with a with-check on insert, so a person cannot
-- write a row under someone else's user_id. There is no update policy: a
-- saved row has nothing to change.

begin;

create table if not exists public.saved_tours (
  user_id uuid not null references auth.users(id) on delete cascade,
  tour_id uuid not null references public.tours(id) on delete cascade,
  saved_at timestamptz not null default now(),
  primary key (user_id, tour_id)
);

alter table public.saved_tours enable row level security;

drop policy if exists saved_tours_select_own on public.saved_tours;
create policy saved_tours_select_own on public.saved_tours
  for select using (user_id = auth.uid());

drop policy if exists saved_tours_insert_own on public.saved_tours;
create policy saved_tours_insert_own on public.saved_tours
  for insert with check (user_id = auth.uid());

drop policy if exists saved_tours_delete_own on public.saved_tours;
create policy saved_tours_delete_own on public.saved_tours
  for delete using (user_id = auth.uid());

commit;

-- Check after running:
--   select polname from pg_policy where polrelid = 'public.saved_tours'::regclass;
