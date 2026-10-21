# Tour Generator — handover

Built 2026-10-20 on `feat/tour-generator`. Design in
`specs/2026-10-20-tour-generator-design.md`, plan in
`plans/2026-10-20-tour-generator.md`. 29 commits, 208 tests.

## Owner steps, in this order

Nothing below has run against the live project. The feature cannot work at
all until the first three are done.

1. **Migration `050_tour_themes.sql`** in the Supabase SQL editor. It changed
   several times during the build — run the version in the repo now. It adds
   `hotspots.themes` with a GIN index, `tours.is_generated`,
   `tours.generated_params`, the two read policies that let an anonymous app
   open a generated round, and `generated_tour_installs`.
   Check after: `select count(*) from hotspots where 'ghosts' = any(themes);`
   should be 15 for Palma.
2. **Migration `051_generator_cities.sql`**. Creates the `generator_cities`
   view and grants it.
   Check after: `select * from public.generator_cities;` — expect Palma only.
   If it errors on `security_invoker`, this project predates Postgres 15;
   delete that clause and re-run. The behaviour is identical either way.
3. **Migration `052_saved_tours.sql`**.
4. **Secret `MAPBOX_TOKEN`** on the project's edge functions. Not the
   publishable key in the app — the function needs its own.
5. **Deploy both functions** from `palma_app`:
   `supabase functions deploy tag-themes --project-ref jqykkyhoxpykhixwgwyw`
   and the same for `generate-tour`.
6. **Sample-tag about twenty places by hand** in admin before running the
   bulk tagging, and look at the result. The model's judgement on what a
   place is *about* is the thing the whole feature rests on; `ghosts` is
   backfilled from the existing `headline` category, the other seven are not.
7. **Bulk-tag Palma's 148 places**, then check it.
8. **Build the APK** and pull rounds.

## What a correct first pull looks like

Measured against live Mapbox with the real ghost places, after the routing
fix. A 2 km `ghosts` **loop from the cathedral**: 5 stops, **about 1.82 km**,
and the app shows that measured figure, not the 2 km asked for.

Other starts differ a lot, which is correct and not a bug:

| Start | Ask | Result |
|---|---|---|
| La Seu | 2 km loop | 1.82 km, 5 stops |
| La Seu | 3 km loop | 2.54 km, 8 stops |
| Plaça d'Espanya | 3 km loop | 3.05 km, 3 stops |
| Plaça d'Espanya | 2 km one-way | 1.97 km, 3 stops |

A loop's geometry begins within ~10 m of the start and ends 0 m from where it
began. If a pull comes back wildly off these, something is wrong with the
deploy rather than with the round.

## Deliberately not built

- **Passim coins, purchases, draw limits, the €2.99 unlock.** Designed in
  conversation and deferred; the design records the intended shape.
- **Rating and sharing a finished round.** The plan excluded both: they want
  the walk to have been finished first, which belongs to the tour screens.
- **A draggable start pin.** The design asked for one; no task built it, so
  the start is always GPS, or the city centre when GPS is unavailable or more
  than 30 km away. This is the one design promise the plan simply missed.
- **A direction reel.** Cut during design: south of the old town is the sea.

## Known gaps, worth a separate pass

- **Decimal separator.** The app prints `1.8 km` in every language; German,
  Spanish and Catalan all write `1,8 km`. Wrong app-wide, not only here, so
  it needs one pass over every distance the app prints rather than a local
  fix.
- **`generate-tour` is unauthenticated** — by design, since anyone may pull
  without an account. But it writes a `tours` row and spends up to six Mapbox
  calls per request. Before public launch it needs rate limiting and a job to
  sweep generated rounds nobody saved.
- **Generated rounds appear in the admin tours list**, one row per tourist
  pull. Worth filtering `is_generated` out of that list before launch, or
  Jose's list fills with other people's rounds.
- **Migration 050 backfills `ghosts` onto every citypack's `headline`
  places**, not only Palma's. Harmless today — the generator only runs in
  narrated cities — but Madrid and Barcelona places carry a tag the admin
  chips will display.
- **A client timeout still pays for the round.** Abandoning the HTTP request
  does not stop the function, so a timeout leaves an orphan tour and the
  person pulls again. The sweep job above covers the row, not the double
  spend.
- **`loadTourStops` ignores the app language** (it omits `lang` from its
  media query, so the first audio file wins). Queued separately; it predates
  this work and affects curated tours too.

## Two things that cost a day and are worth remembering

**The test suite cannot see Mapbox.** Twenty-two green Deno tests stubbed
`fetch` with a reply Mapbox never actually sends. Two real defects — a
`radiuses` parameter that made *every* live call fail with `NoSegment`, and
the start point never being routed at all — were invisible to the suite and
obvious the moment the code made a real call. Anything touching the
Optimization API should be checked against it, not against a stub.

**Read every migration, not the one that created the table.** `017_tours.sql`
defines `price_sek`; `027_euro_pricing.sql` renames it to `price_cents`. A
ruling made from the first file alone would have failed the insert on every
single pull.
