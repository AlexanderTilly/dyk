# Tour Generator — design

**Date:** 2026-10-20
**Status:** design, approved scope; not yet planned

---

## Why

Passim has 148 narrated places in Palma. A visitor can reach them two ways
today: wander and hope one triggers, or walk one of six hand-made tours.

Both leave something on the table. Wandering is the product's charm but it is
nobody's plan for an afternoon. And the hand-made tours were built to collect a
subject rather than to be walked — "Mysteries and Legends of Palma" gathers all
fifteen ghost stories into **17.9 km and three and a half hours**, while twelve
of those fifteen places sit within 800 metres of each other.

The content is already walkable. The tours are not. The generator is the piece
that turns one into the other: tell it how far you want to walk and what kind
of story you are in the mood for, and it cuts a route out of what already
exists.

Its first output on the ghost theme will be visibly better than the hand-made
tour on the same places. That is the clearest argument for building it.

## What the person does

A slot machine with three reels and a lever.

| Reel | Positions |
|---|---|
| Distance | 1 km · 2 km · 3 km · 5 km |
| Shape | Loop (back to the start) · One way |
| Theme | the eight below |

Pull the lever, get a round. Don't like it — pull again. Walking it uses the
tour screens the app already has.

Afterwards: rate it, save it to walk again, share it to a friend.

## The eight themes

Measured against the real places, with the tightest cluster each one has:

| Theme | Places | Within 800 m of each other |
|---|---|---|
| Food & drink | 18 | 17 |
| Churches & convents | 17 | 15 |
| Ghosts & Legends | 15 | 12 |
| Walls, gates & towers | 14 | **6** |
| Palaces & noble houses | 13 | 13 |
| Old shops & crafts | 12 | 9 |
| The sea & the harbour | 12 | 8 |
| Modernisme | 10 | 10 |

Seven of the eight can fill a 2–4 km round from their own cluster. **Walls,
gates and towers cannot** — the gates ring the old city and the castles sit
well outside it, so that theme needs 5 km before it stops being a march
between landmarks. The wheel has to know this; see Constraints.

Ghosts & Legends is already the `headline` category in the database, exactly
those fifteen rows. The other seven need tagging.

## Goals

- A round someone actually wants to walk: a tight cluster of related places,
  not a technically valid path between scattered ones.
- The stated distance is real walking distance, within a tolerance the app
  shows honestly.
- Pulling again gives a genuinely different round, not a reshuffle of the same
  five places.
- The result is a real tour in the database — walkable with the existing
  screens, editable in admin, saveable and shareable.

## Non-goals for this version

Decided by the owner, 2026-10-20:

- **No Passim coins, no purchases, no subscription, no draw limit.** The
  economy was designed in this conversation and then deliberately deferred:
  first prove the round is worth walking. This also keeps the feature clear of
  Apple's and Google's in-app purchase rules, which the app does not implement
  yet, and clear of the loot-box framing that a paid lever on a slot machine
  would invite.
- **No direction reel.** South of the old town is the sea: two places, at any
  radius. A wheel where one of four positions can never pay out is a broken
  machine, and with 118 of 148 places inside one kilometre, distance and theme
  already shape the round. Direction can return for a city that spreads out.
- **No AI-written linking narration.** The places already have their stories.
  What the generator sells is the arrangement.
- No offline. The app streams audio today; the generator changes nothing there.

## Anti-goals

Things that would mean failure even if the code works:

- A round that is the right length and dull — the distinction the whole
  feature lives or dies on.
- A pull that returns nothing. Every reel combination the wheel offers must be
  able to pay out.
- A round that says 3 km and walks 5.
- A round that doubles back along the street it just used.

## Constraints, measured

**The places are not spread evenly.** From the old town: 72 places within
500 m, 118 within 1 km, 128 within 2 km, 135 within 3 km. Going from 1.5 km to
3 km adds nine places in total. A 5 km round is therefore mostly walking
between widely spaced points — real, and thin.

**South is the sea.** Two places, at any radius.

**The routing machinery already exists.** `dyk-admin/src/pages/ToursPage.tsx`
calls `optimized-trips/v1` with `roundtrip=true` for loops and
`directions/v5` for fixed orders, both on the walking profile. It orders the
stops, closes the loop and returns real distance and geometry. This is the hard
part and it is in production.

**Mapbox limits:** 25 coordinates per Optimization request; one request per
candidate route regardless of how many stops it carries; roughly 100,000
requests a month before billing starts. Ten candidates per pull is ten
requests, which puts the ceiling near 10,000 pulls a month at no cost. Confirm
current figures at mapbox.com/pricing before relying on them.

**The Mapbox token is shared** with the app, the admin panel and the website.
A generator that calls Mapbox from the client would spread it further still.

## How it works

### Themes are tagged once, not computed per pull

Keyword matching does not work. Searching the descriptions for ghost words
matches 54 places; for royal words, 126 of 148 — because the texts are long and
mention everything in passing. A word in a subordinate clause does not make a
place a ghost story.

Deciding what a place is *about* needs judgement, so it is a language-model
job. But it is a **one-time job per place**, run in admin beside the existing
translate and narrate buttons, with the result stored on the hotspot. A place
can carry more than one theme.

The model is already here: `supabase/functions/translate-content` calls
Claude with `ANTHROPIC_API_KEY` from Supabase secrets. Tagging copies that
pattern — no new provider, no new key, no owner step.

**Storage, my call:** a `themes text[]` column on `hotspots` with a GIN
index, not a join table. A place carries a handful of short tags, the
generator asks "which places have this theme", and an array answers that in
one indexed query without a join nobody else needs. The admin edits it as
checkboxes beside the category.

After tagging, a pull costs nothing but a database query and a routing call.
This is why the two-step "cheap preview, expensive commit" idea discussed
earlier is not needed: there is no per-pull language-model cost to avoid.

### The generator runs server-side

**My call, not the owner's.** A new edge function beside `generate-tts`.

Three reasons. The Mapbox token stays off the client. The app and any later
web version behave identically rather than drifting. And when the draw limit
and coins arrive, the counter has to be server-side anyway or it is bypassed
by changing the clock on the phone.

### Generated tours are ordinary tours

**My call.** A generated round is written to `tours` and `tour_stops` like any
other, with a flag marking it as generated and the reel settings stored
alongside it.

Everything downstream then works unchanged: the app's tour detail and active
tour screens, the stop sequence, the arrival radii, admin's editor. A tour
Jose likes can be promoted to a curated one by clearing the flag.

### Picking the places

Sketched, not prescribed — the builder should expect to tune this against real
output:

1. Start from the person's position, or a chosen point.
2. Take the places carrying the chosen theme within a radius derived from the
   distance budget.
3. Choose a subset that can plausibly fit the budget, biased toward a compact
   cluster rather than a line.
4. Route it: Optimization API, `roundtrip=true` for a loop, walking profile.
5. Compare the returned distance to the target. Add or drop a place and route
   again if it is outside tolerance.
6. Build several candidates this way and keep the best.

**Tolerance: ±15%**, my call, and the app shows the real distance rather than
the asked-for one. A round that says 3 km and walks 3.4 is fine if it says so.

**Variety across pulls** is a goal in its own right. Remember which places the
last few rounds used and push them down the ranking, so the second pull is a
different walk rather than the same five places in a new order.

## Left to the builder

- The scoring function: how to weigh compactness, theme fit, variety and how
  little the route repeats itself.
- How many candidates per pull, traded against latency — a pull should feel
  like a pull, not a progress bar.
- What a one-way round means for a start point that is the person's position:
  where it is allowed to end.
- How the wheel hides combinations that cannot pay out — greying the position,
  skipping it, or quietly widening the radius. The constraint is the
  anti-goal: no pull returns nothing.
- Whether a saved generated tour belongs to the person or to the city.

## Who can use it, and where

Both decided by the owner on 2026-10-20, on my recommendation.

**Anyone can pull and walk; saving asks for an account.** Passim works
anonymously today, on an install id, and putting a registration form in front
of a slot machine would lose the people most likely to enjoy it. A pull, a
route and a walk need no identity. Keeping one does — so the save button is
where the sign-in prompt belongs, at the moment the person has already
decided the thing is worth keeping.

**The generator only appears in cities whose places have audio.** Madrid has
148 hotspots and no narration; Zürich 75, Barcelona 30, all silent. A
generator let loose there would produce a correct route through places that
say nothing — a tourist pulls the lever, gets a handsome map, puts in
headphones and hears silence. That is worse than the feature not being there.
The condition is already in the data, so it costs nothing to enforce: a city
qualifies when enough of its places carry narration, and the next city
switches itself on as it is recorded.

## Calls I made, so you can check them

Beyond the three above, these were settled rather than asked, because a
sensible builder would land in the same place and none of them changes what
gets built:

- **Where the machine lives:** inside the existing Tours screen, as the first
  thing on it, rather than a new tab. The bottom bar is already four items,
  and a generated round *is* a tour.
- **Start point:** the person's current position by default, with the pin
  draggable on the map before pulling. Asking for an address before a slot
  machine would be a strange door to put in front of a lever.
- **Theme names:** written in English first and run through the existing
  translator for es/ca/de, like every other string in the app.

## What this does not answer

The coin economy, the draw limit, the €2.99 unlock and Pro — all designed in
conversation on 2026-10-20 and deferred to a later version. They are recorded
here only so the next design does not start from nothing:

- Free: ten pulls a day, not carried over; an eleventh costs a Passim coin.
- Coins: one per kilometre walked, or bought.
- A generated tour costs €2.99 to unlock for free users, nothing for Pro.
- Pro still gets ten free pulls a day.

Anything built now should avoid making those harder — which is most of the
reason the generator runs server-side.
