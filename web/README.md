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
| `app.js` | one audio element shared by every play button |
| `privacy/` | **skeleton, not legal text** — see below |
| `assets/` | logo, hero artwork, the four map pins (219 kB total) |
| `_headers` | Netlify / Cloudflare syntax; Loopia ignores it |

## Before it goes live

**The store links are `href="#"`.** Both of them, in the hero and in the
closing section — they carry `data-store="ios"` and `data-store="android"`, so
they are quick to find. The page cannot convert anything until these point
somewhere.

**The privacy page is a skeleton with the gaps marked.** Apple and Google both
refuse an app without a real policy, so this is a launch blocker and not a
nicety. The headings are the ones Passim actually needs to answer, given what
the app does; someone qualified writes the answers.

**`hello@passimexplore.com` has to exist.** It is the only contact route on
the page.

## The audio

The hero and the four clips stream real narration straight from Supabase
storage — public URLs, the same files the app plays. Nothing is copied here,
so re-recording a story updates the site too.

They are long, several minutes each, and `preload="none"` means nothing is
fetched until someone presses play. The page costs 219 kB until then.

One `Audio` element is shared by every button. Two stories talking over each
other is the fastest way to make a page about listening feel broken.

## What the page claims, and why only that

Palma, and not Europe. 149 places there are finished and narrated in four
languages; everything else in the database is written but silent. A page
promising fifteen cities breaks the moment someone opens the app in Rome, and
the first thing they would do is ask for their money back — except it is free,
so they would simply delete it.

When another city is narrated end to end, change the numbers here. Not before.
