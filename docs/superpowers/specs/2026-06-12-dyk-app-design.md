# Did You Know! (DYK) — Designspec v1

**Datum:** 2026-06-12
**Status:** Godkänd av Alexander (baserad på 12 design-mockups)

## Vision

Turistapp som ger platsbaserade "Did you know?"-ögonblick: gå runt i en stad, få notiser med historier, fun facts, nyheter och lokala erbjudanden vid hotspots. Palma de Mallorca är pilotstad.

## Varumärke & stil

- **Namn:** Did You Know! (DYK). Testappen "Palma Explorer" pensioneras.
- **Logo:** Sticker-stil — vit/gul skript-text med tjock svart kontur, glödlampa + kartnål.
- **Färger:** Gul `#FFC107` (primär), svart `#1A1A1A`, krämvit `#FAF6EE`, grönt `#22C55E` endast för "Downloaded"-badges.
- **Tema:** Ljust + mörkt läge, båda designade (följ systeminställning).
- **Typografi:** Rubriker i fet condensed versal stil (Archivo Black eller liknande), brödtext system-sans.
- **Kategori-ikoner:** Tecknade sticker-badges (History-kolonn, Fun Facts-megafon, Headlines-tidning, Hot Deals-prislapp, City Pack-låda). Används även som kartnålar.

## Navigationsstruktur

Bottom tabs (5): **Explore · Nearby · City Packs · Saved · Profile**
Global header på alla flikar: profil-ikon (vänster), DYK-logo (mitten), notisklocka med badge (höger).

## Onboarding (första start)

1. **Welcome** — logo, landmärkes-collage, "Explore cities. Discover stories. Unlock hidden gems." + START EXPLORING
2. **Choose Your Interests** — multiselect: History 🏛️, Fun Facts 💡, Headlines 📰, Hot Deals 🔥 + Continue
3. **Location Access** — "We use your location to discover places around you." + Enable Location
4. **Notifications** — "Get notified when you're near something worth discovering." + Enable Notifications
5. **Ready to Explore** — "You're all set." + Let's Go → Explore-fliken

## Sidor

### Explore (hem/dashboard)
- Hero med stadsbild + stor toggle-knapp: **EXPLORING (aktiv, tap to pause)** / **START EXPLORING** (pausad). Styr geofencing globalt.
- **Active interests** — rad med kategori-badges, ✓ på aktiva. Tap togglar.
- **Mini-karta** — kategori-pins runt användarens position. Tap → Nearby-fliken.
- **Latest notifications** — kortlista: kategori-label, avstånd, titel, beskrivning. Hot Deal-kort har CODE-knapp (t.ex. "CODE PALMA25").

### Nearby (fullskärmskarta)
- Sökfält ("Search places, landmarks, deals...") + filterknapp.
- Kategorifilter-rad (badges) — togglar pins per kategori.
- Mapbox-karta med kategori-pins (custom markers av badge-bilderna), blå användar-prick, lokaliserings-FAB.
- Tap pin → hotspot-detaljsida.

### City Packs (butik)
- Tabs: All Cities / Downloaded / Available.
- Pack-kort: stadsbild, MB-storlek, namn, land, rating, antal hotspots, beskrivning, DOWNLOAD-knapp. "RECOMMENDED"-badge på närmaste/utvald stad.
- Download = hämtar allt innehåll (JSON + ljud + bilder) för offline.

### Saved (bokmärken)
- Filterchips: All / Places / Deals / City Packs / Articles.
- Sektioner med horisontella kort: Saved Places, Saved Deals (med %-badge), Saved City Packs (Downloaded/Available-status).
- Offline-banner: "Download city packs for offline access — No roaming. No worries. Just explore."

### Profile
- Avatar, namn, level ("Level 12 Explorer"), motto.
- Statistik-rad: Cities Explored / Hotspots Visited / Deals Redeemed / City Packs Downloaded.
- **Go Premium**-banner → View Plans.
- My Activity: Visited Hotspots, Saved Items, Redeemed Deals, Downloaded Packs.
- **Achievements** — badge-samling (First Steps 5 hotspots, City Explorer 50, Deal Hunter 10 deals, World Traveler 10 cities, Globe Trotter 20 cities — låsta visas gråa med hänglås).
- Menyrad: Edit Profile, Settings, Help & Support, About, Sign Out.

### Hotspot-detaljsida (design saknas — bygg i samma stil)
- Hero-bild, kategori-badge, namn, undertitel, år.
- Audio-player (om ljud finns), beskrivningstext, bildgalleri.
- Save-bokmärke, dela-knapp.
- För deals: CODE-ruta + "Show this code"-instruktion.

## Affärsmodell

- **Freemium per stad:** några hotspots gratis per stad, fullt City Pack låses upp (köp eller premium).
- **Hot Deals:** valbar intressekategori. Lokala företag betalar för synlighet; CODE-inlösen gör effekten mätbar.
- **Premium** (senare): obegränsade downloads, exklusivt innehåll, inga deals om man vill.

## Beteenderegler

- Notiser triggas endast: när EXPLORING är på + kategorin matchar användarens intressen + (v1-test) varje gång man går in i zonen.
- STOP EXPLORING stoppar geofencing helt (batteri + integritet).
- Alla triggade notiser sparas i notishistoriken (klockan).
- Besökta hotspots loggas → stats + achievements.

## Teknisk grund

- **App:** Flutter (befintlig palma_app-kodbas byggs om till DYK).
- **Backend:** Supabase-projektet "DYK" (`jqykkyhoxpykhixwgwyw`) — schema finns (citypacks, hotspots, hotspot_media, hot_deals, user_purchases) och utökas med: `hotspots.category`, `hot_deals.redeem_code`, `user_interests`, `saved_items`, `user_visits`, `notification_log`.
- **Admin:** dyk-admin (React + Vite, lokal) — utökas med kategori-fält och deal-koder.
- **Karta:** Mapbox med custom marker-bilder.
- **Auth:** Supabase Auth (email + Apple/Google senare) — krävs för Saved/Profile/köp.

## Utanför v1

Premium-köpflöde (IAP), Articles-innehållstyp, achievements-motor (visas statiskt), riktig video på Welcome, AR, flerspråk, offline-zip-pipeline (v1 cachar via nedladdning per fil).
