# passimexplore.com

The Passim landing page. Static HTML — no build step, no dependencies, no
framework. Open `index.html` and it works.

That is deliberate. A one-page site that needs `npm install` before anyone can
change a headline is a site nobody changes.

## Run it locally

```bash
cd web && python -m http.server 4399
```

Then open <http://localhost:4399>.

## What's here

| | |
|---|---|
| `index.html` | the brand page: what Passim is, which cities exist |
| `palma/` | the city page — the one that sells Palma |
| `palma.js` | the live map: 148 real places, clustered and playable |
| `data/palma.json` | those places, baked at build time |
| `styles.css` | all of it |
| `app.js` | one shared audio element, used by every player on the site |
| `privacy/` | **skeleton, not legal text** — see below |
| `assets/` | Palma photography, the four map pins, the brand pin |
| `_headers` | Netlify / Cloudflare syntax; Vercel and Loopia ignore it |
| `vercel.json` | headers and clean URLs on Vercel |

Vercel serves this folder directly: the project's Root Directory is `web`,
which is also where Vercel looks for `vercel.json` — a copy at the repo root
would simply never be read.

## Why there are two pages

The root is the brand; `/palma/` is the city. Splitting them now costs nothing
and means `/madrid/` and `/zurich/` are a folder each rather than a rebuild —
which matters if the plan is to spread quickly.

It also lets the root be honest. It names Palma as live and the rest as being
written, instead of a single page quietly implying a continent.

## The map

`/palma/` draws a real Mapbox map of the 148 narrated places, clustered, with
category filters and a card that plays the story.

The reference artwork is a picture of a city, not a map of one — dropping true
coordinates onto it would put the cathedral in the wrong street. So it serves
as the backdrop while Mapbox loads and as the fallback if Mapbox never
arrives, and the real thing is what you end up looking at.

Two things that bite here:

- `.map-stage .map-canvas` is two classes deep on purpose. Mapbox's stylesheet
  sets `.mapboxgl-map { position: relative }` and loads *after* ours, so a
  single-class rule loses, the container collapses to zero height, and Mapbox
  quietly draws into its 300px default somewhere off-stage.
- Mapbox paint values are literals, never `var(--amber)`. Mapbox parses paint
  with its own engine, logs a rejection and skips the layer. That has cost this
  project an afternoon before.

Mapbox is a megabyte and a half and loads only when the section is about to be
seen.

**The token is the app's token.** Public tokens are meant to be public, but
this one is shared with the app and the admin panel. A separate URL-restricted
token for passimexplore.com would mean a scraped website token cannot spend the
app's quota — worth doing before this page gets traffic.

## Regenerating the places

```bash
node tool/build_web_places.js
```

Reads production and rewrites `web/data/palma.json`. Only places with both
coordinates and English narration go in: a pin that opens to silence is worse
than no pin. That is why the page says 148 and the database says 149.

## Before it goes live

**The store links are `href="#"`.** All four of them — they carry
`data-store="ios"` and `data-store="android"`, so they are quick to find. The
page cannot convert anything until these point somewhere.

**The privacy page is a skeleton with the gaps marked.** Apple and Google both
refuse an app without a real policy, so this is a launch blocker and not a
nicety. The headings are the ones Passim actually needs to answer given what
the app does; someone qualified writes the answers.

**`hello@passimexplore.com` has to exist.** It is the only contact route on
the page.

## The audio

The story block and all four cards stream real narration straight from
Supabase storage — public URLs, the same files the app plays. Nothing is
copied here, so re-recording a story updates the site too.

They run for minutes each, and `preload="none"` means nothing is fetched until
someone presses play. One `Audio` element is shared by every button: two
stories talking over each other is the fastest way to make a page about
listening feel broken. Pressing a second button stops the first and resets its
timer.

## Images

Everything is WebP. The hero and the closing band are the app's own Palma
header photograph, cropped to two shapes; the four cards come from real
hotspot images in Supabase storage.

About 500 kB loads above the fold. The cards are `loading="lazy"` and arrive
on scroll. If that needs to come down, the closing band's photograph is the
one to attack — it is a CSS background, so the browser fetches it even though
it sits far below the fold.

Note the app's `assets/images/catedral_1.jpg`, `bellver_1.jpg` and
`placa_major_1.jpg` are 1×1 placeholder files, not photographs. They look like
real assets in a directory listing and are not.

## The phone in the hero

Drawn in HTML and CSS rather than screenshotted. It stays sharp at any size,
and it cannot quietly go out of date the way a captured screen does — but it
also will not update itself when the app changes. If the app's player stops
looking like that, this is hand-written and has to be hand-corrected.

## What the page claims, and why only that

Palma, and not Europe. 149 places there are finished and narrated in four
languages; everything else in the database is written but silent. A page
promising fifteen cities breaks the moment someone opens the app in Rome.

When another city is narrated end to end, change the numbers here. Not before.
