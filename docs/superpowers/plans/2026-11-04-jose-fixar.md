# Jose's eleven — the six we promised

**Date:** 2026-11-04 · **From:** 1.5.0+8 → 1.6.0+9 · **Branch:** main

Six of Jose's eleven cards have published answers promising a fix in the next
build. The other five wait on his reply and are not touched here: nearest
hotspot as stop one, Museums as a generator theme, profile questions, and the
arrival animation.

Migration `054_subcategory_constraint.sql` is Alexander's to run. Not touched.

---

## What is actually wrong, verified

Every line below was checked in the source before planning, not taken on
trust.

| # | Where | Found |
|---|---|---|
| 1 | `hotspot_detail_screen.dart` | `'THE STORY'` (412), `'Read more'`/`'Read less'` (438), `'DID YOU KNOW?'` (457), `'💡 FACT $index'` (546), `'LISTEN TO THE STORY'` (915) — all literals |
| 2 | `i18n.dart` | `cat_otium` reads `'Leisure'` in **all four** languages (87, 394, 688, 982) |
| 2 | `nearby_tab.dart:33-37` | `_categoryMeta` hardcodes **four** labels, not one: History, Leisure, Stories & Legends, Hot Deals |
| 3 | `i18n.dart` | `theme_walls_gates` in four languages, plus `THEME_LABELS` in two edge functions and the admin |
| 4 | `tour_generator_screen.dart` | reels size independently of label length; Spanish breaks "Circular" |
| 5 | `hotspot_detail_screen.dart:905+` | player row runs past the right edge on a narrow phone |
| 6 | `geofence_*.dart` | `repeat(12000)` + `LocationAccuracy.high`, every tick, all day |

## Decisions taken before building

**Keys never change, only labels.** `walls_gates` stays `walls_gates` and
`otium` stays `otium`. A key rename would mean migrating tagged rows for a
word nobody stores — and the whole point of item 3 is that the label was
wrong, not the data.

**`_categoryMeta` loses its labels entirely.** The map keeps the emoji and
reads the name from `cat_<key>`, which already exists in all four languages.
Jose reported Leisure; the other three are the same bug one row down, and
fixing one of four would be a promise half kept.

**The battery work must not weaken arrivals.** That is the trade this task
lives or dies on: polling less saves power and risks walking past a place in
silence. The rule is that accuracy and frequency relax only when relaxing them
cannot cost an arrival — far from every hotspot, or not moving. Active tours
and navigation have their own tracking and are left alone.

**Tests first where a test can exist.** Layout and i18n are testable at a
given width and locale; background battery behaviour is not, so item 6 gets
its reasoning written down instead of a green tick that proves nothing.

## The work

### 1 · Strings out of the widgets (me)
Move the six literals to `i18n.dart` with new keys, all four languages.
`listen_story` already exists — use it rather than adding a second.
Then sweep `lib/screens/` for other literals in user-facing `Text(...)`.

### 2 · Leisure, and the three beside it (me)
`cat_otium` → Ocio / Oci / Freizeit. `_categoryMeta` drops its label column
and calls `tr('cat_$key')`.

### 3 · Castles, gates & towers (me)
Label only, in four places: `theme_walls_gates` in i18n, `THEME_LABELS` in
`supabase/functions/generate-tour` and `tag-themes`, and the admin's chips.
ES *Castillos, puertas y torres* · CA *Castells, portes i torres* ·
DE *Burgen, Tore & Türme*.

### 4 · Reels that fit their words (agent)
The reel already has a 14 px floor and two lines from October. Spanish still
breaks mid-word, so the column widths must follow the longest label in the
*current* locale rather than a fixed flex. Extend the four-language legibility
test to assert no word is split and nothing overflows.

### 5 · The player on a 320 dp screen (me)
The row holding the title, ±10 s, progress and the speed button overruns.
Make it fit at 320 dp with a widget test at that width.

### 6 · Battery (agent)
Two changes, both reversible:
- **Adaptive tick and accuracy.** Far from any hotspot, or not moving: longer
  interval, coarser fix. Within reach of one: today's behaviour exactly.
- **Rest when nothing can happen.** Pause overnight and after a long stillness,
  waking on movement.
Leave the step counter and `_checkSupportReplies` working — they ride the same
tick and must not be starved by a longer interval.

## Checks before the APK

- `flutter analyze --no-fatal-infos lib test` clean of warnings and errors
- `flutter test` green, including the extended legibility test and the new
  narrow-screen test
- `flutter build apk --release`
- Version `1.6.0+9`, committed, **not pushed and not deployed**

---

## What actually happened

**Item 1 was far bigger than six strings.** The sweep the plan asked for found
**28** hardcoded English literals across eleven files, not the six Jose named.
Nine were on screens he had not reached yet; the rest surfaced only once a
guard test walked the widgets instead of the translations map.

Two of them were not merely untranslated but **stale branding**: the onboarding
screen still read "Welcome to Palma Explorer" and the map screen's title bar
said "Palma Explorer". That is the first screen a new user sees, and the app
has been called Passim for months. The existing rebrand test checks the
translations map and Info.plist — widget literals were its third blind spot.

**The player card overflowed in every language, not just German.** The test
written for item 5 fails at 360 dp in English too, against the old code. Jose
noticed it on his phone; it was there on everyone's.

**New guard:** `test/i18n/no_hardcoded_strings_test.dart` walks `lib/screens`
and `lib/widgets` and fails on English prose in a `Text(...)`. The parity test
proves a key exists in four languages; it can never prove a widget bothered to
call it. This is the one that can.

**Left alone deliberately:** `support@diduknow.app` in the paused screen. It is
an address rather than prose, and it is still the live support route — guessing
a new one would break the only way a locked-out user can reach anyone.

**Translations are mine and unreviewed.** Roughly 120 strings of Spanish,
Catalan and German were written here. They are careful but they are not a
native speaker's. Jose should read them before this reaches users — that is
twenty minutes of his time and it is the right twenty minutes.
