# Profile questions and personalisation

**Date:** 2026-11-13 · **From:** 1.7.0+10 → 1.8.0+11

Six optional questions that let Passim put the right things first. Jose's
spec, Alexander's decisions, and the consent wording he published to Jose —
used verbatim, because it has been shown to the client.

---

## The decision that shapes the whole design

**Answers never filter. They only reorder.** Nothing disappears because of
what someone answered — a person who picks "food" still sees every ghost
story, just further down. That rules out a whole class of complaint ("the app
hid things from me") and makes a wrong guess cheap.

**No account means nothing leaves the phone.** The server table is keyed to
`auth.uid()` and exists only for signed-in people. An anonymous user's
answers live in `SharedPreferences` and are uploaded the moment they sign in.
This is not a limitation we worked around — it is the safest version, and it
is what the published privacy text already promises: *"otherwise they are only
stored on your phone."*

That removes the worst option, which would have been personal preferences
keyed to a device id that the person cannot see, cannot reach and did not
knowingly create.

## When the welcome screen appears

Not at first launch — Alexander's call, and Jose's point that download already
has enough steps.

**After the first finished walk, or after three listened stories, whichever
comes first.** Three because it is the point where someone has stopped
sampling and started using the app: one story is curiosity, three is a
decision. A finished tour is a stronger signal still, so either qualifies.

Shown once, skippable, and the questions live in Profile for ever after.

## Consent, kept separate from the answers

Using the answers to choose which offers someone sees is profiling under
GDPR, so it is a second, explicit yes — and a separate row, with the time and
the version of the text that was shown. Without it the answers still improve
the person's own recommendations; only offer ranking is withheld.

The three texts are published to Jose and are used **verbatim**. They are
reproduced in `lib/i18n/i18n.dart` under `profile_consent_*`, and the English
is the source: the other three languages are translations of it.

## Data model

| | |
|---|---|
| `profile_answers` | one row per signed-in user: `user_id`, `question_version`, `answers jsonb`, `updated_at` |
| `profile_consents` | `user_id`, `offers_consent bool`, `consent_version`, `decided_at` |
| `profile_answer_stats` | a view: counts per question and option. No user id, no install id, admin only |

`question_version` is stored with every answer set so the questions can be
rewritten later without silently reinterpreting old answers as if they were
replies to the new ones.

**Security model, in order of what stops what:**

1. `revoke all` on both tables from `anon` and `authenticated`. The tables are
   not reachable from the client at all.
2. All access goes through `security definer` functions that filter on
   `auth.uid()`, so the user id is never a parameter the client supplies.
3. RLS on both tables as a second line, in case a future grant is added by
   someone who did not read this file.
4. The admin view exposes counts only and is granted to admins via the
   existing `is_admin()` helper.

## What the answers reorder

| Question | Orders |
|---|---|
| 2 · which stories | tour themes, and the generator's theme reel |
| 6 · local recommendations | Leisure subcategories in Nearby |
| 3 · how they explore | tour length |
| 4 · who they explore with | family-friendly places |
| 5 · what makes it irresistible | Hot Deals — **only with consent** |

Jose's warning is carried into the code: *selecting family activities does not
mean the user has children.* Nothing infers an attribute that was not given.

## Order of work

Migration, then functions, then APK — as before. Version `1.8.0+11`,
committed, **not pushed and not deployed**: a peer cannot approve a
deployment, and Alexander has not spoken in this session.

## Open, needs a human

**The privacy policy needs the company's legal name.** It is left as an
explicit `TODO` in the text. I will not invent a company name.

The consent wording should be read by someone qualified before launch. It is
careful, but it is not legal advice, and it is the text that carries the
lawful basis.
