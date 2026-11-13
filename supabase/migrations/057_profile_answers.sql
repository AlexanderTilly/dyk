-- 057_profile_answers.sql — the optional interest questions, and the separate
-- consent to use them for choosing offers.
-- Idempotent. Run in Supabase → SQL Editor as the default (postgres) user.
--
-- This is the first personal data Passim stores about a person's preferences,
-- so the shape is deliberate:
--
-- 1. Only signed-in people get a row here. Someone with no account keeps their
--    answers in SharedPreferences on the phone, and they are uploaded when
--    they sign in. The alternative — keying preferences to an install id —
--    would create a profile the person cannot see, cannot reach and never
--    knowingly made. It is also what the published privacy text promises:
--    "otherwise they are only stored on your phone."
--
-- 2. The tables are NOT reachable from the client. Everything goes through
--    security-definer functions that read auth.uid() themselves, so the user
--    id is never a parameter the caller supplies and cannot be forged.
--
-- 3. RLS is on anyway, as a second line, in case someone grants access later
--    without reading this.
--
-- 4. Consent to personalised offers is a separate row with its own timestamp
--    and the version of the text that was shown. It is profiling under GDPR,
--    so it has to be given separately and be withdrawable — and we must be
--    able to say WHICH words someone agreed to, not merely that they did.

begin;

create table if not exists public.profile_answers (
  user_id uuid primary key references auth.users(id) on delete cascade,
  -- Which set of questions these answers belong to. Rewriting the questions
  -- later must not silently reinterpret old answers as replies to new ones.
  question_version text not null,
  -- { "q1": ["A"], "q2": ["B","D"], ... } — the option letters, nothing else.
  answers jsonb not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.profile_consents (
  user_id uuid primary key references auth.users(id) on delete cascade,
  offers_consent boolean not null,
  -- The version of the wording the person was actually shown.
  consent_version text not null,
  decided_at timestamptz not null default now()
);

alter table public.profile_answers enable row level security;
alter table public.profile_consents enable row level security;

-- Second line. The functions below are the first.
drop policy if exists profile_answers_own on public.profile_answers;
create policy profile_answers_own on public.profile_answers
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists profile_consents_own on public.profile_consents;
create policy profile_consents_own on public.profile_consents
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- First line: the client cannot touch these tables directly at all.
revoke all on public.profile_answers from anon, authenticated;
revoke all on public.profile_consents from anon, authenticated;

-- ---------------------------------------------------------------------------
-- The only way in. Each reads auth.uid() itself.
-- ---------------------------------------------------------------------------

create or replace function public.save_profile_answers(
  p_answers jsonb,
  p_question_version text
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  insert into public.profile_answers (user_id, question_version, answers)
       values (auth.uid(), p_question_version, p_answers)
  on conflict (user_id) do update
          set answers = excluded.answers,
              question_version = excluded.question_version,
              updated_at = now();
end $$;

create or replace function public.get_profile_answers()
returns table (question_version text, answers jsonb, updated_at timestamptz)
language sql
security definer
set search_path = public
as $$
  select a.question_version, a.answers, a.updated_at
    from public.profile_answers a
   where a.user_id = auth.uid();
$$;

-- Deleting must actually delete, not hide. "You can change or delete your
-- answers at any time" is a promise in the published privacy text.
create or replace function public.delete_profile_answers()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  delete from public.profile_answers where user_id = auth.uid();
  delete from public.profile_consents where user_id = auth.uid();
end $$;

create or replace function public.set_offers_consent(
  p_granted boolean,
  p_consent_version text
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  insert into public.profile_consents (user_id, offers_consent, consent_version)
       values (auth.uid(), p_granted, p_consent_version)
  on conflict (user_id) do update
          set offers_consent = excluded.offers_consent,
              consent_version = excluded.consent_version,
              decided_at = now();
end $$;

create or replace function public.get_offers_consent()
returns table (offers_consent boolean, consent_version text, decided_at timestamptz)
language sql
security definer
set search_path = public
as $$
  select c.offers_consent, c.consent_version, c.decided_at
    from public.profile_consents c
   where c.user_id = auth.uid();
$$;

revoke all on function public.save_profile_answers(jsonb, text) from public;
revoke all on function public.get_profile_answers() from public;
revoke all on function public.delete_profile_answers() from public;
revoke all on function public.set_offers_consent(boolean, text) from public;
revoke all on function public.get_offers_consent() from public;

grant execute on function public.save_profile_answers(jsonb, text) to authenticated;
grant execute on function public.get_profile_answers() to authenticated;
grant execute on function public.delete_profile_answers() to authenticated;
grant execute on function public.set_offers_consent(boolean, text) to authenticated;
grant execute on function public.get_offers_consent() to authenticated;

-- ---------------------------------------------------------------------------
-- What the admin may see: totals, and nothing else.
-- ---------------------------------------------------------------------------
--
-- No user id, no install id, no row that belongs to a person. Jose needs to
-- know that 40% chose "mysteries and legends"; he has no business knowing who
-- did. security_invoker = false so the count is complete, and execute is
-- granted only through is_admin().

drop view if exists public.profile_answer_stats;

create view public.profile_answer_stats
  with (security_invoker = false) as
select a.question_version,
       q.key   as question,
       opt     as option,
       count(*)::int as answers
  from public.profile_answers a
 cross join lateral jsonb_each(a.answers) as q(key, value)
 cross join lateral jsonb_array_elements_text(q.value) as opt
 group by a.question_version, q.key, opt;

revoke all on public.profile_answer_stats from anon, authenticated;

create or replace function public.admin_profile_stats()
returns table (question_version text, question text, option text, answers int)
language sql
security definer
set search_path = public
as $$
  select s.question_version, s.question, s.option, s.answers
    from public.profile_answer_stats s
   where public.is_admin();
$$;

revoke all on function public.admin_profile_stats() from public;
grant execute on function public.admin_profile_stats() to authenticated;

commit;

-- Check after running:
--   select * from public.admin_profile_stats();
--   -- empty until someone answers; as a non-admin it must return nothing
--   -- rather than erroring.
--
--   select * from public.profile_answers;
--   -- as anon or authenticated this must be PERMISSION DENIED. If it returns
--   -- rows, the revoke above did not take and the client can read everyone's
--   -- preferences.
