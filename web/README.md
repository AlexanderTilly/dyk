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
| `index.html` | the whole page |
| `styles.css` | all of it |
| `app.js` | one shared audio element, plus the map's pins |
| `privacy/` | **skeleton, not legal text** — see below |
| `assets/` | Palma photography, the four map pins, the brand pin |
| `_headers` | Netlify / Cloudflare syntax; Loopia ignores it |
| `../vercel.json` | serves this folder if the site goes on Vercel |

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
