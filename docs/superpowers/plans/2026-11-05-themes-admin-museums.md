# Theme tooling in admin, and Museums as the ninth

**Date:** 2026-11-05 · **From:** 1.6.0+9 → 1.7.0+10

Two pieces. **A** gives Jose the tools to tag — sort, filter and edit themes
from the hotspot list. **B** adds `museums` as a ninth generator theme.

## Verified against live data before planning

| Claim | Found |
|---|---|
| 48 of 148 untagged | ✓ exactly |
| 8 hotspots with `subcategory = 'museums'` | ✓ — and **5 of them already carry other themes**, so the backfill must append |
| `updateField` can report a save that never happened | ✓ `HotspotsPage.tsx:282-287` — optimistic, no rollback, and an RLS-blocked update returns 0 rows with no error |
| Table already 10 columns wide | ✓ an 11th would push Access further off Jose's screen |
| An unknown theme breaks the generator | ✓ `generate-tour/index.ts:80` returns 400 `Unknown theme`, so the function must ship before the APK |

## Found while checking, not in the brief

**`the_sea` has only two tagged places.** `selectPlaces` needs three, so that
reel position cannot pay out at any distance, from anywhere — the design's
named anti-goal, live today. Adding a ninth theme does not cause this and does
not fix it. What fixes it is tagging, which is what part A is for.

Current spread: churches 19, food_drink 16, palaces 15, ghosts 15,
walls_gates 13, old_shops 12, modernisme 9, **the_sea 2**.

## A · Tagging tools in the hotspot list

1. **Sort by Subcategory**, null last.
2. **Theme filter** beside the category buttons, with *Untagged*. Client-side:
   the list is already loaded per citypack, so a round trip buys nothing.
3. **Themes column**, edited in the row, multiple values, from `TOUR_THEMES`.

Constraints that shape it:

- **Writes must be believed only when the row comes back.** `updateField` is
  optimistic with no rollback, and RLS refuses silently. The theme write
  verifies with `.select()` and rolls back the optimistic edit when the row
  does not return.
- **`themes` is a whole-array write**, and *Tag untagged* plus the `tag-themes`
  function write the same column. Editing is disabled while tagging runs, for
  the reason already written at the button.
- **A row must not move out from under the pointer.** Sorting and filtering
  settle when the user changes them, not while they are mid-edit.
- **No new width.** A popover, not a column of chips — Access is already
  clipped on Jose's screen.

## B · Museums, key `museums`

Nine places to add the key: `lib/models/themes.dart`, `dyk-admin/src/themes.ts`,
`generate-tour` `THEME_LABELS`, `tag-themes` `THEMES` and its prompt, i18n in
four languages, and the tests that pin each list.

**Migration** backfills `museums` onto `subcategory = 'museums'`, appending
rather than replacing — five of the eight already have themes. Idempotent, like
the ghosts backfill in 050. Eight rows in Palma, so no model is needed, and
`tag-themes` would not reach them anyway: it only touches untagged rows.

**The reels must hold nine themes in four languages**, which the existing
legibility test already covers once the key is in the list.

**Simulated against live data:** from the old town 1, 2, 3 and 5 km all work
(3, 4, 5, 5 stops). From Plaça d'Espanya 1 km fails, from Portixol 1 and 2 km
fail. That is the honest shape of eight museums in one quarter, and the
`too_few` notice already says so in all four languages.

## Order that matters

`generate-tour` must be deployed **before** the APK reaches anyone. An older
function meeting a newer app returns 400 `Unknown theme`, which the app shows
as a flat failure. Older apps send eight themes and are unaffected, so the
function can go first safely.

## Checks

- `flutter analyze --no-fatal-infos lib test` clean of warnings and errors
- `flutter test`, `deno test` on both functions, `npm test` and `npm run build`
  in dyk-admin
- Version `1.7.0+10`, committed, **not pushed and not deployed**

---

## What the simulation actually gave

Run against live data, with the function's own one-shot widening included —
which the brief's figures appear to have left out:

| From | 1 km | 2 km | 3 km | 5 km |
|---|---|---|---|---|
| Old town (La Seu) | 3 stops | 4 | 4 | 4 |
| Plaça d'Espanya | too_few | 3* | 4* | 4 |
| Portixol | too_few | too_few | too_few | 4* |

\* needed the widening. The brief expected Portixol to work at 3 km; it does
not. Eight museums in one quarter do not reach that far, and the counts in the
old town settle at four rather than five because the cluster caps out.

This is honest behaviour rather than a fault: the `too_few` notice already
says so in four languages, and it sits beside the theme reel where the remedy
is — turn the wheel.

## Two reel positions now, not one

`the_sea` has **two** tagged places and `selectPlaces` needs three, so it
cannot pay out from anywhere at any distance. `museums` has eight and works
from the centre outward. Both argue the same thing: the generator is limited
by tagging, not by code, which is what part A exists to unblock.
