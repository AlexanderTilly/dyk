# Tour Generator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn Palma's 148 narrated places into walks shaped to the person — pick a distance, a shape and a theme, pull the lever, get a route you can walk now.

**Architecture:** Themes are tagged onto hotspots once by Claude and stored in an array column. A new edge function picks a themed subset near the start point, routes it with Mapbox Optimization, and writes the result into the existing `tours`/`tour_stops` tables. The app gets a slot-machine screen; everything after the pull reuses the tour screens that already exist.

**Tech Stack:** Flutter (app), Supabase edge functions on Deno (generator + tagger), React/TypeScript (admin), Mapbox Optimization API v1, Anthropic Claude via the pattern in `translate-content`.

**Spec:** `docs/superpowers/specs/2026-10-20-tour-generator-design.md`

## Global Constraints

- The eight theme keys, exactly: `food_drink`, `churches`, `ghosts`, `walls_gates`, `palaces`, `old_shops`, `the_sea`, `modernisme`. The same list lives in the app, the admin and the edge functions.
- `ghosts` is the existing `headline` category — those 15 hotspots get the tag automatically, not by asking Claude.
- Distance tolerance **±15%**, and the app shows the measured distance, never the asked-for one.
- **Mapbox Optimization v1 takes at most 12 coordinates.** The admin already guards this (`ToursPage.tsx`, `located.length >= 3 && <= 12`). Never send more.
- Mapbox profile is `walking`; the token stays in Supabase secrets and never reaches the client.
- Reel values: distance `1 | 2 | 3 | 5` km, shape `loop | one_way`.
- `walls_gates` is offered only at 5 km — six places within 800 m is not a short walk.
- The generator is offered only in cities where at least 20 hotspots carry English narration.
- Anyone may pull and walk. Saving requires a signed-in account.
- Migrations are run by the owner in the SQL editor; never applied automatically.

## Review Focus

1. **A theme with too few places near the start** — e.g. `modernisme` at 1 km from the far west. The pull must say so plainly, not return a two-stop "tour" or an empty map. Pinned in Task 4.
2. **Mapbox returns an error or fewer waypoints than sent** — a half-ordered route must never be written to `tours`. Pinned in Task 5.
3. **Two pulls in a row returning the same round** — variety is a stated goal, so a repeat is a defect, not luck. Pinned in Task 4.
4. **A pull with no connection** — the app must fail visibly within seconds rather than spinning, the way narration did on 2026-09-30. Pinned in Task 8.
5. **A start point outside every qualifying city** — the wheel must not appear at all, rather than generating a route through silence. Pinned in Task 6.

---

### Task 1: Themes in the database, and one list everyone shares

**Files:**
- Create: `supabase/migrations/050_tour_themes.sql`
- Create: `lib/models/themes.dart`
- Create: `test/models/themes_test.dart`
- Create: `../dyk-admin/src/themes.ts`
- Create: `../dyk-admin/src/themes.test.ts`

**Interfaces:**
- Produces: `const tourThemes` (Dart) and `TOUR_THEMES` (TS), both `List<String>`/`string[]` of the eight keys in the order given in Global Constraints; `themeLabel(String key)` in Dart reading i18n key `theme_<key>`.

- [ ] **Step 1: Write the failing tests**

`test/models/themes_test.dart` pins the list verbatim against Global Constraints, asserts keys match `^[a-z][a-z_]*$`, and asserts `ghosts` is present. `../dyk-admin/src/themes.test.ts` pins the same eight keys in the same order, with a comment naming the Dart file as its twin.

- [ ] **Step 2: Run both to verify they fail**

Run: `flutter test test/models/themes_test.dart` and `cd ../dyk-admin && npx vitest run src/themes.test.ts`
Expected: FAIL, files not found.

- [ ] **Step 3: Write the migration**

`050_tour_themes.sql`, idempotent, with a comment block explaining why an array and not a join table:
- `alter table public.hotspots add column if not exists themes text[] not null default '{}'`
- `create index if not exists hotspots_themes_idx on public.hotspots using gin (themes)`
- `alter table public.tours add column if not exists is_generated boolean not null default false`
- `alter table public.tours add column if not exists generated_params jsonb`
- Backfill: `update public.hotspots set themes = array['ghosts'] where category = 'headline' and not themes @> array['ghosts']`

- [ ] **Step 4: Write the two constant files**

Keys only, with the label coming from i18n. Each file's comment names the other as the twin that must change with it.

- [ ] **Step 5: Run both test suites to verify they pass**

Run: `flutter test` and `cd ../dyk-admin && npm test`
Expected: PASS, no new analyzer or type errors.

- [ ] **Step 6: Commit**

```bash
git add supabase/migrations/050_tour_themes.sql lib/models/themes.dart test/models/themes_test.dart
git commit -m "feat(themes): theme keys, and a column to hold them"
```

---

### Task 2: Tagging a hotspot's themes with Claude

**Files:**
- Create: `supabase/functions/tag-themes/index.ts`
- Create: `supabase/functions/tag-themes/pick.ts`
- Create: `supabase/functions/tag-themes/pick_test.ts`

**Interfaces:**
- Consumes: the eight keys from Task 1 (copied into the function; edge functions cannot import from `lib/`).
- Produces: `POST /functions/v1/tag-themes` with `{ hotspot_ids: string[] }` → `{ tagged: { id: string, themes: string[] }[] }`. Admin-only, same `is_admin()` gate as `translate-content`.
- Produces: `cleanThemes(raw: unknown, allowed: string[]): string[]` in `pick.ts`.

- [ ] **Step 1: Write the failing test**

`pick_test.ts`, run with `deno test`. `cleanThemes` keeps only allowed keys, drops unknown ones, de-duplicates, caps at three, and returns `[]` for null, a string, or a number. Three is the cap because a place that is about everything is about nothing, and the wheel offers one theme at a time.

- [ ] **Step 2: Run it to verify it fails**

Run: `deno test supabase/functions/tag-themes/pick_test.ts`
Expected: FAIL, module not found.

- [ ] **Step 3: Implement `cleanThemes`**

- [ ] **Step 4: Run it to verify it passes**

- [ ] **Step 5: Implement the function**

Copy the shape of `translate-content/index.ts`: CORS headers, `is_admin()` gate, `ANTHROPIC_API_KEY`, `model: 'claude-opus-5'`, and `output_config.format.type: 'json_schema'` with a schema of `{ themes: string[] }` whose items are an enum of the eight keys. Send the hotspot's name, subtitle and description. The prompt must say that a theme belongs only when the place is *about* it — a passing mention of the sea in a sentence does not make a church a maritime place. Pass the result through `cleanThemes`, then write `themes` with the service role.

- [ ] **Step 6: Deploy and tag one hotspot by hand**

Run: `supabase functions deploy tag-themes --project-ref jqykkyhoxpykhixwgwyw`
Expected: tagging "The Walled-In Lady of La Seu" returns `ghosts`; tagging "Bar Bosch" returns `food_drink`. A wrong answer here means the prompt, not the code.

- [ ] **Step 7: Commit**

---

### Task 3: Tagging from the admin

**Files:**
- Modify: `../dyk-admin/src/pages/HotspotsPage.tsx`
- Create: `../dyk-admin/src/themeChips.tsx`
- Create: `../dyk-admin/src/themeChips.test.tsx`

**Interfaces:**
- Consumes: `TOUR_THEMES` from Task 1; the `tag-themes` endpoint from Task 2.
- Produces: `<ThemeChips themes={string[]} onChange={(next: string[]) => void} />`.

- [ ] **Step 1: Write the failing test**

jsdom render test, in the style of `Fullscreen.test.tsx`: chips render one per theme, the selected ones carry `.is-on`, clicking toggles and calls `onChange` with the new array, and an unknown key stored on a hotspot still renders rather than vanishing.

- [ ] **Step 2: Run it to verify it fails**

- [ ] **Step 3: Implement `ThemeChips` and wire it into the hotspot editor**

Beside the subcategory select. Add a "Suggest themes" button calling `tag-themes` for the open hotspot, and a bulk button on the list header for every hotspot with empty `themes`. Reuse `generateNarration`'s direct-fetch pattern, not `functions.invoke`.

- [ ] **Step 4: Run tests and build to verify they pass**

Run: `cd ../dyk-admin && npm test && npm run build`

- [ ] **Step 5: Commit**

---

### Task 4: Choosing which places make a round

**Files:**
- Create: `supabase/functions/generate-tour/select.ts`
- Create: `supabase/functions/generate-tour/select_test.ts`

**Interfaces:**
- Produces:
  - `type Place = { id: string; lat: number; lng: number; themes: string[]; name: string }`
  - `type Pick = { places: Place[]; reason?: 'too_few' }`
  - `selectPlaces(places: Place[], opts: { start: { lat: number; lng: number }; km: number; theme: string; exclude: string[]; seed: number }): Pick`

- [ ] **Step 1: Write the failing tests**

- Returns between 3 and 12 places (the Optimization ceiling from Global Constraints).
- A theme with fewer than 3 places inside the radius returns `{ places: [], reason: 'too_few' }` — **Review Focus 1**.
- Two different seeds over the same input return different sets — **Review Focus 3**.
- Places listed in `exclude` are not chosen while enough others remain.
- Every returned place carries the asked-for theme.
- The radius grows with `km`: a 1 km ask must not reach a place 2 km away.

- [ ] **Step 2: Run them to verify they fail**

Run: `deno test supabase/functions/generate-tour/select_test.ts`

- [ ] **Step 3: Implement `selectPlaces`**

Straight-line radius ≈ `km * 1000 / 3` from the start, since a loop's stops sit well inside its length. Rank candidates by closeness to the start and to each other, seed the shuffle so the same seed repeats and a new one varies, then take as many as the budget suggests — roughly one stop per 250 m, clamped to 3–12.

- [ ] **Step 4: Run them to verify they pass**

- [ ] **Step 5: Commit**

---

### Task 5: Routing the round and writing it down

**Files:**
- Create: `supabase/functions/generate-tour/index.ts`
- Create: `supabase/functions/generate-tour/route.ts`
- Create: `supabase/functions/generate-tour/route_test.ts`

**Interfaces:**
- Consumes: `selectPlaces` from Task 4.
- Produces: `buildRoute(places, shape, token, fetchImpl): Promise<{ ordered: Place[]; meters: number; geojson: object } | { error: string }>` in `route.ts`.
- Produces: `POST /functions/v1/generate-tour` with `{ lat, lng, km, shape, theme, exclude?, citypack_id }` → `{ tour_id, title, meters, minutes, stops: [...], geojson }`.

- [ ] **Step 1: Write the failing tests**

`route_test.ts` with a stubbed `fetchImpl`, no network:
- A normal reply reorders the places by `waypoint_index` and returns the trip's distance.
- A reply with fewer waypoints than places returns `{ error }` and no ordering — **Review Focus 2**.
- A non-200 reply returns `{ error }` carrying the status.
- More than 12 places is rejected before any call is made.

- [ ] **Step 2: Run them to verify they fail**

- [ ] **Step 3: Implement `buildRoute`**

`optimized-trips/v1/mapbox/walking` with `roundtrip=true&source=first` for `loop`, and `roundtrip=false&source=first&destination=last` for `one_way`. Mirror the radiuses trick in `ToursPage.tsx:417` so stops snap to the street rather than down dead ends.

- [ ] **Step 4: Run them to verify they pass**

- [ ] **Step 5: Implement the function**

Up to 6 candidates: call `selectPlaces` with a fresh seed each time, route it, keep the first whose distance is within ±15% of the ask, otherwise the closest. Insert into `tours` with `is_generated = true`, `generated_params` holding the reel settings and seed, `is_published = false`, `price_cents = 0`; insert `tour_stops` in the returned order with `hotspot_id` set. Title from the theme label and the distance. Return `too_few` as a 422 with the theme named, not a 500.

- [ ] **Step 6: Deploy and pull once by hand**

Run: `supabase functions deploy generate-tour --project-ref jqykkyhoxpykhixwgwyw`
Expected: a 2 km `ghosts` loop from the cathedral returns 5–8 stops and a measured distance between 1.7 and 2.3 km.

- [ ] **Step 7: Commit**

---

### Task 6: Which cities offer the generator

**Files:**
- Create: `supabase/migrations/051_generator_cities.sql`
- Modify: `lib/services/dyk_repository.dart`
- Create: `test/services/generator_city_test.dart`

**Interfaces:**
- Produces: SQL view `generator_cities (citypack_id, narrated_count)`, listing citypacks with ≥ 20 English-narrated hotspots.
- Produces: `Future<Set<String>> loadGeneratorCities()` on `DykRepositoryBase` and its fake.

- [ ] **Step 1: Write the failing test**

With a fake repository: a city in the set offers the generator, one outside it does not, and an empty set hides it everywhere — **Review Focus 5**. Assert against a pure `bool generatorAvailable(String? citypackId, Set<String> cities)` so the rule is testable without a widget.

- [ ] **Step 2: Run it to verify it fails**

- [ ] **Step 3: Write the migration and the repository method**

The view counts `hotspot_media` rows with `media_type = 'audio'` and `lang = 'en'` joined to hotspots, grouped by citypack. Comment it with why: a correct route through silent places is worse than no feature.

- [ ] **Step 4: Run the test to verify it passes**

- [ ] **Step 5: Commit**

---

### Task 7: The machine

**Files:**
- Create: `lib/screens/tour_generator_screen.dart`
- Create: `lib/widgets/reel.dart`
- Create: `test/widgets/reel_test.dart`
- Modify: `lib/i18n/i18n.dart`

**Interfaces:**
- Consumes: `tourThemes` (Task 1), `generatorAvailable` (Task 6).
- Produces: `Reel<T>({ required List<T> values, required T value, required ValueChanged<T> onChanged, required String Function(T) label })`.

- [ ] **Step 1: Write the failing test**

Widget test: the reel shows its current value, dragging moves to the neighbouring value and calls `onChanged` once, and the value at either end does not wrap past the list.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/widgets/reel_test.dart`

- [ ] **Step 3: Implement `Reel` and the screen**

Three reels in the order Distance · Shape · Theme, amber on navy, with the lever as a full-width button reading `tr('generate_tour')`. `walls_gates` is absent from the theme reel unless distance is 5 — the Global Constraint, enforced in the widget so no pull can ask for it.

- [ ] **Step 4: Add the strings in all four languages**

Keys `theme_<key>` for the eight, plus `generate_tour`, `generating_tour`, `tour_too_few`, `tour_failed`. English and Swedish written here; es/ca/de through the existing translator.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test` — including the translation parity test, which fails on any key missing from a language.

- [ ] **Step 6: Commit**

---

### Task 8: Pulling the lever, and what comes back

**Files:**
- Create: `lib/services/tour_generator.dart`
- Create: `test/services/tour_generator_test.dart`
- Modify: `lib/screens/tour_generator_screen.dart`
- Modify: `lib/screens/tabs/tours_tab.dart`

**Interfaces:**
- Consumes: the `generate-tour` endpoint (Task 5).
- Produces: `Future<GeneratedTour> generate({ required double lat, required double lng, required int km, required String shape, required String theme, List<String> exclude })`, throwing `TourTooFew` or `TourGenerationFailed`.

- [ ] **Step 1: Write the failing tests**

With an injected HTTP client:
- A normal reply parses into `GeneratedTour` with stops in order.
- A 422 throws `TourTooFew` carrying the theme.
- A timeout throws `TourGenerationFailed` **within 25 seconds** — **Review Focus 4**. No request may hang: narration spun for minutes on 2026-09-30 because nothing capped it.
- Each call sends the previous round's place ids as `exclude`.

- [ ] **Step 2: Run them to verify they fail**

- [ ] **Step 3: Implement the service and wire the screen**

The lever calls `generate`, shows a pulling state, then pushes the existing `TourDetailScreen` with the returned tour. `TourTooFew` shows `tr('tour_too_few')` beside the theme reel rather than a dialog — the fix is to turn a wheel, so the message belongs at the wheel. Add the generator as the first card in `tours_tab.dart`, hidden when `generatorAvailable` is false.

- [ ] **Step 4: Run the full suite and the analyzer**

Run: `flutter test && flutter analyze lib/`
Expected: all pass, no new findings.

- [ ] **Step 5: Build the APK and pull three rounds on a phone**

Run: `flutter build apk --release`
Expected: a 2 km ghosts loop walks as a loop, the measured distance is shown rather than the asked-for one, and a second pull gives different places.

- [ ] **Step 6: Commit**

---

### Task 9: Keeping a round

**Files:**
- Create: `supabase/migrations/052_saved_tours.sql`
- Modify: `lib/services/tour_generator.dart`
- Modify: `lib/screens/tour_generator_screen.dart`
- Create: `test/services/saved_tour_test.dart`

**Interfaces:**
- Consumes: `GeneratedTour` (Task 8), `AuthService` (`lib/services/auth_service.dart`).
- Produces: `Future<SaveResult> saveTour(String tourId)` returning `SaveResult.saved`, `SaveResult.needsAccount` or `SaveResult.failed`.

A generated tour is written whether or not anyone keeps it, so this is about
ownership, not storage: a kept round must survive the next pull and show up in
Saved.

- [ ] **Step 1: Write the failing tests**

With a fake auth service: a signed-out caller gets `needsAccount` and **no
write is attempted**; a signed-in caller gets `saved`; saving the same tour
twice stays `saved` rather than erroring.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/services/saved_tour_test.dart`

- [ ] **Step 3: Write the migration and the method**

`saved_tours (user_id, tour_id, saved_at)` with both ids as the primary key so
a second save is a no-op, and RLS allowing a person to read and write only
their own rows.

- [ ] **Step 4: Wire the save button**

On the result, beside Start. `needsAccount` opens the existing `AuthScreen`
and saves on return — the prompt belongs at the moment the person has already
decided the round is worth keeping, not in front of the lever.

- [ ] **Step 5: Run the suite to verify it passes**

- [ ] **Step 6: Commit**

**Not in this plan:** rating a finished round and sharing it to a friend. Both
are in the design under what the person does, and both want the walk to have
been finished first — which is the tour screens' business, not the
generator's. They are a follow-up once a generated round has proved worth
walking.

---

## Owner steps

Migrations `050` and `051` run by hand in the Supabase SQL editor. Edge functions `tag-themes` and `generate-tour` deployed with the CLI from `palma_app`. The admin's bulk tagging run once over Palma's 148 places, with the result checked before anyone pulls a lever.
