# Tours — Guided Walking Loops (City Packs → Tapas Route engine)

**Date:** 2026-06-23
**Status:** Approved design, ready for implementation planning

## Summary

A reusable "guided tour" engine for the DYK app. A **Tour** is a curated, ordered
loop of stops a user walks through — arriving at each stop in order, unlocking a
story + audio (history) or a venue offer (tapas). The same engine powers the
existing **City Packs** concept (renamed **Tours** in the UI) and the upcoming
**Tapas Route**. Tours are created in the admin panel and unlocked in the app
(free for now; payment wired later).

## Goals

- One engine drives every tour type (history walk, food & drink / tapas, custom).
- Feels like a real guided walk: map with the walking path, numbered stops in
  order, "you've arrived" geofence check-ins, saved progress, completion screen.
- Built to stay fast and stable: route geometry precomputed in admin, lazy media,
  fewer active geofences.
- Future-proof for real payments and offline download without a rebuild.

## Non-Goals (deferred)

- Real payments (Stripe / IAP) — ownership model is prepared, button unlocks free.
- Offline download of media — media streams; images cached via `cached_network_image`.
- Badges / achievements, reviews, social sharing.
- Turn-by-turn voice navigation (we show the path + distance, not spoken turns).

## Data Model

Three new tables on top of the existing `citypacks` / `hotspots` / `hot_deals` /
`user_purchases` schema.

### `tours`
A curated loop, belongs to a city (`citypack_id`).
- `id` uuid pk
- `citypack_id` uuid → `citypacks(id)` (which city)
- `type` text check in (`history_walk`, `food_drink`, `custom`)
- `title`, `subtitle`, `description` text
- `hero_image` text (storage path)
- `price_sek` integer default 0 (0 = free)
- `is_published` boolean default false
- `distance_meters` integer, `est_minutes` integer (auto-computed from route)
- `route_geojson` jsonb — **precomputed walking path** (one Mapbox Directions call
  at admin time); the app only renders it, no runtime routing calls
- `sort_order` integer default 0
- `created_at` timestamptz default now()

### `tour_stops`
Ordered stops. A stop EITHER links an existing hotspot OR carries its own venue
content (tapas), in the same table.
- `id` uuid pk
- `tour_id` uuid → `tours(id)` on delete cascade
- `order_index` integer
- `hotspot_id` uuid null → `hotspots(id)` (history walks reuse hotspot content)
- Own-content fields (used when `hotspot_id` is null): `title`, `blurb`, `lat`,
  `lng`, `image` (storage path), `audio_path` (storage path), `offer_text`,
  `redeem_code`
- `arrival_radius_meters` integer default 40 (geofence check-in radius)
- `created_at` timestamptz default now()

### `tour_progress`
Per-user visit tracking, drives "X/Y done" and completion.
- `user_id` uuid → `auth.users(id)` on delete cascade
- `tour_id` uuid → `tours(id)` on delete cascade
- `stop_id` uuid → `tour_stops(id)` on delete cascade
- `visited_at` timestamptz default now()
- unique(`user_id`, `stop_id`)

### Ownership / unlock
Reuse existing `user_purchases` + `has_purchased()`. Add a nullable `tour_id`
column to `user_purchases` (keep `citypack_id` for backward compat). A
`has_tour(p_tour_id)` security-definer function mirrors `has_purchased`. Unlocking
inserts a purchase row for free now; the same plumbing accepts a real payment later.

### RLS / RPCs
- `tours`, `tour_stops`: public read of published rows (anon + authenticated);
  writes via admin role only (existing admin-role pattern).
- `tour_progress`: own-rows RLS. Writes via a `record_tour_visit(p_tour_id,
  p_stop_id)` security-definer RPC (same pattern as pickpocket/presence).
- `unlock_tour(p_tour_id)` security-definer RPC inserts the free purchase row.

## App Experience

### TOURS tab (renamed from "City Packs")
- Lists tours for the user's current city, grouped by type:
  *History Walks*, *Food & Drink* (Tapas Route lives here).
- Each tour card: hero image, title, "4 stops · 1.2 km · ~45 min", price / unlocked
  status.

### Tour detail screen
- Hero, description, ordered stop-list preview, price.
- Locked → **Unlock** button (free now). Unlocked → **Start tour**.

### Active tour (the core, "map route + stop list")
- Map with the precomputed walking path + numbered brand-style stop pins.
- Bottom horizontal card strip: visited (✓), "you're near" (yellow ring), upcoming.
- Reuses the existing geofence engine, but seeded with ONLY this tour's stops
  (fewer regions → better battery/stability) at their `arrival_radius_meters`.
- On arrival at the next stop → notification "You've arrived at Stop 2" → opens the
  stop view: story + audio (history) or offer + optional `redeem_code` (tapas).
- Progress saved per stop; pause/resume works.
- All stops done → **Tour complete 🎉** screen.

### Tapas stop view
Venue name, "Try their [dish]", image, and — if `redeem_code` present — a code box
to show at the venue (same visual style as current Hot Deals).

## Admin (Tour Builder)

New **Tours** page in the admin panel.
- Tour list per city: create / edit / publish, drag to reorder.
- Tour editor:
  - Base fields: title, type, description, hero image (upload), price (0 = free),
    published.
  - **Stop builder** — ordered, drag-to-sort list. Add stop → either pick an
    existing hotspot (dropdown) OR "custom stop" (tapas: title, blurb, location via
    **map-pick** with manual lat/lng fallback, image + audio upload, offer text,
    redeem code).
  - **"Generate walking path"** button → one Mapbox Directions call with stops in
    order → saves `route_geojson`; auto-computes `distance_meters` + `est_minutes`.
- Same `tours` / `tour_stops` tables for every type — a Tapas Route is built
  exactly like a History Walk, differing only by `type` and stop content.

## Performance & Stability

- Route geometry precomputed in admin → zero Directions calls in the app.
- Tour list loads light (no media); stop media fetched lazily on open; images cached.
- Active tour seeds the geofence engine with only the tour's stops.
- Progress writes go through a small security-definer RPC.

## Components (isolation)

- `models/tour.dart`, `models/tour_stop.dart` (+ progress as a Set of visited stop ids).
- Repository: `loadTours(citypackId)`, `loadTourStops(tourId)`,
  `loadTourProgress(tourId)`, `unlockTour(tourId)`, `recordTourVisit(tourId, stopId)`.
- App screens: tours list (TOURS tab), tour detail, active-tour map screen, stop
  sheet, completion screen.
- Admin: `ToursPage.tsx` (list + editor + stop builder + route generation).
- DB migration `017_tours.sql` (+ RPCs).

## Open questions / defaults chosen

- UI label: **TOURS**.
- Admin location entry: **map-pick** with manual lat/lng fallback.
- Unlock: **free** now via `user_purchases`; payment later.
- Media: **streamed** now; offline later.
