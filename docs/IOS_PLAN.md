# iOS-plan — funktionsparitet med Android

Status: iOS-projektet är genererat och grundkonfigurerat (bundle `app.diduknow`,
behörighetstexter, bakgrundslägen, ikoner, iOS 14 som mål, Podfile).
Kvar är bakgrundsmotorn, byggkedjan och App Store-kraven.

---

## 1. Varför bakgrundslagret måste skrivas om

Android-appen kör en **förgrundstjänst** som tickar var 12:e sekund
(`geofence_task_handler.dart`). Varje tick gör fem saker:

1. Kollar om användaren gått in i en hotspot-zon → notis
2. Kollar deal-zoner + targeting → notis + `deal_reach_log` (debitering)
3. Kollar om användaren kommit till en ny stad → välkomstnotis
4. Ackumulerar steg från GPS-rörelse
5. Rapporterar närvaro till `live_sessions` (admin-kartan + deal-publiken)

På iOS finns ingen motsvarighet. `flutter_foreground_task` kör där ca **30 sek
var 15:e minut** — en turist skulle passera katedralen och få notisen en kvart
senare. Hela kedjan ovan måste därför byggas om mot iOS egen modell.

## 2. Vald arkitektur på iOS

**Grundläge — region monitoring.** iOS väcker appen när användaren korsar en
geofence-gräns, även om appen är helt stängd. Det är Apples avsedda modell,
kostar nästan ingen batteri, och `geofencing_api` (redan i pubspec) stödjer det.

Begränsning: **max 20 regioner** samtidigt per app. Palma har långt fler
hotspots. Lösning: registrera dynamiskt om de 20 närmaste och byt ut listan när
användaren rört sig tillräckligt långt.

**Aktivt läge — kontinuerlig position.** När en tour pågår, eller när
"Take me there"-navigationen är igång, slår vi på `allowsBackgroundLocationUpdates`.
Då strömmar iOS positioner kontinuerligt precis som i en navigationsapp. Det är
motiverat, Apple accepterar det för den typen av funktion, och det ger samma
precision som Android under just de moment där precision betyder något.

`GeoFencingService` (lib/services/geo_fencing_service.dart) finns redan och gör
nästan exakt rätt sak — men anropas aldrig; bara `dispose()` används idag. Den
blir grunden för iOS-vägen i stället för att slängas.

## 3. Funktion för funktion

| Funktion | Android idag | iOS-lösning |
|---|---|---|
| Hotspot-notiser | 12 s-tick + avståndskoll | Region monitoring, 20 närmaste roterande |
| Deal-notiser + targeting | Samma tick, targeting lokalt | Samma regionmodell; targeting-koden återanvänds oförändrad |
| Reach-debitering | `deal_reach_log` från isolat | Anropas i region-enter-callbacken |
| Stad-välkomst | Avstånd till stadscentrum | Stor region (radie i km) per publicerad stad |
| Steg | GPS-delta, 0,75 m/steg | **CMPedometer** via `pedometer`-paketet — riktiga steg, mer exakt än Android |
| Live-närvaro | Var 12:e sekund | Vid varje regionhändelse + kontinuerligt när appen är öppen eller tour pågår |
| Ljuduppspelning i bakgrund | just_audio_background | Fungerar redan; `audio` background mode tillagt |
| Karta | mapbox_maps_flutter | Fungerar; kräver hemlig nedladdningstoken vid bygge |
| Notistryck → detaljsida | NotificationRouter | Oförändrad |

**Konsekvens att känna till:** iOS live-närvaro blir glesare än Android när
appen är stängd. Admin-kartan och deal-publikens siffra kommer därför att
underskatta iOS-användare i viloläge. Alternativet vore kontinuerlig
positionering dygnet runt, vilket dränerar batteri och riskerar avslag i
granskningen. Rekommendation: acceptera glesheten och markera iOS-sessioner i
`live_sessions` så siffrorna kan tolkas rätt.

**Steg blir bättre på iOS, inte sämre.** CMPedometer räknar verkliga steg och kan
läsa historik bakåt, vilket gör stegsegmenten i Deals mer träffsäkra där.
Övervägande värt: byta Android till samma modell senare via health-API:er.

## 4. Byggkedjan (Codemagic)

1. `codemagic.yaml` med iOS-workflow — Flutter-version, Xcode-version, cache
2. **App Store Connect API-nyckel** (Issuer ID, Key ID, `.p8`) laddas upp i
   Codemagic → automatisk signering och uppladdning till TestFlight
3. **Mapbox hemlig token** som miljövariabel + `.netrc`-skript före `pod install`
   — utan den misslyckas bygget direkt
4. Bundle-id `app.diduknow` registreras i Apple Developer Portal
5. Första bygget → TestFlight → intern testning på riktig iPhone

## 5. App Store-krav utöver Play

- **Bakgrundsposition** granskas hårdare än hos Google. Reviewer-anteckningen
  ska förklara att appen är en gå-guide och att notiserna är hela produkten.
  Onboarding-samtycket vi redan har hjälper.
- **Kontoradering i appen** krävs — finns redan (Settings → Delete account). ✓
- **Sign in with Apple** krävs *inte*, eftersom appen bara har e-post/lösenord
  och ingen tredjepartsinloggning. ✓
- **Privacy nutrition labels** i App Store Connect — ska matcha Data safety-svaren
  på Google, annars ser det inkonsekvent ut.
- **IAP:** samma fråga som på Android. Tas priser ut måste StoreKit användas —
  Stripe är förbjudet för digitalt innehåll. Idag visas priser men allt låses upp
  gratis; det måste lösas på båda plattformarna samtidigt.
- `ITSAppUsesNonExemptEncryption = false` i Info.plist sparar en fråga per bygge.

## 6. Ordning och uppskattning

| Steg | Innehåll | Tid |
|---|---|---|
| 1 | Codemagic-konto, API-nyckel, Mapbox-token, första grönt bygge | 0,5–1 dag |
| 2 | Abstrahera bakgrundslagret bakom ett gemensamt gränssnitt | 0,5 dag |
| 3 | iOS region monitoring + rotation av 20 närmaste | 2–3 dagar |
| 4 | Steg via CMPedometer | 0,5 dag |
| 5 | Närvaro + reach-debitering på iOS-vägen | 0,5 dag |
| 6 | Tour-läge med kontinuerlig position | 1 dag |
| 7 | Test på riktig iPhone ute i stan, justering | 2–3 dagar |
| 8 | App Store-material, labels, granskning | 1 dag + väntetid |

**Cirka 1,5–2 veckors arbete**, plus Apples granskningstid.

Steg 1 bör göras först och separat: ett grönt tomt bygge i TestFlight bevisar att
signering, pods och Mapbox-token fungerar, innan någon ny logik skrivs.
