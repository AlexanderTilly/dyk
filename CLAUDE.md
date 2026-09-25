# Passim app (palma_app) — Claude-kontext

Flutter-app "Passim" (f.d. DYK), tourist audio guide. Supabase-projekt `jqykkyhoxpykhixwgwyw`. Adminpanel i `C:\Users\tilly\dyk-admin`. Röstassistenten Michelle (läser den här databasen) i `C:\Users\tilly\michelle`.

## Flera Claude-sessioner i samma repo — regler

Det här repot redigeras från mer än en chatt (en Passim-chatt och Michelle-chatten i callero-flow). Alla jobbar i **samma mapp och samma git** — inget mergas mellan chattar, men:

1. **En session i taget per repo.** Avsluta och committa innan du byter chatt.
2. **Börja alltid med `git log --oneline -10` och `git status`** för att se vad den andra sessionen gjorde.
3. Migrationer appliceras **av ägaren i Supabase SQL Editor**, aldrig automatiskt. Kolla `supabase/migrations/` mot vad som faktiskt körts innan du antar att en tabell finns i produktion (044 var t.ex. inte applicerad 2026-09-24).
4. Push sker via GitHub Desktop som AlexanderTilly; terminalen nekas push.

## Pågående arbete (uppdatera när något ändras)

- **Michelle v2 — kundsupport i tre delprojekt.** Specar och planer i `docs/superpowers/specs/` och `docs/superpowers/plans/` med prefix `2026-09-24-support-thread` (A) och `2026-09-25-support-inbox-app` (C).
  - **A klart 2026-09-25:** migrationer 045 + 046 applicerade i produktion (tabell `support_messages`, statustrigger, gäst-RPC:er `support_thread`/`support_reply`, owner-select på `support_tickets`). Adminpanelens tråd + svarsruta ligger på dyk-admin `master` (mergad från `support-thread`).
  - **C kodklart 2026-09-25, väntar på ägarsteg:** inkorg i appen — `support_screen.dart`, `support_thread_screen.dart`, `SupportApi`/`SupportSeenStore`/`SupportReplyChecker`, `install_id` på nya ärenden, lokala notiser vid personalsvar (app-öppning/resume + Android-tjänsten var 5:e minut), migration 047. Alla 8 tasks + helhetsgranskning klara (115 tester, `flutter analyze` rent). **047 är ÄNDRAD efter granskning** — innehåller nu även en trigger (`support_tickets_first_message`) som ger varje nytt ärende sitt första meddelande automatiskt; utan den öppnades varje ny tråd tom för alltid (kritiskt fynd, fixat innan applicering). Kvar: ägaren applicerar 047, bygger APK lokalt (senaste försöket kraschade på Gradle OOM — `org.gradle.jvmargs=-Xmx8G` i `android/gradle.properties` mot 16 GB RAM; sänk till `-Xmx4G` eller stäng andra program och försök igen — Codemagics iOS-flöde har inget Gradle-steg och drabbas inte), installerar och testar kedjan live, pushar för iOS/TestFlight.
  - **B (ej påbörjat):** Michelle svarar på ärenden med godkännandespärr.
  - **D (föreslaget):** riktig push (FCM/APNs) — krävs för notiser när appen är stängd på iOS.
- SDD-ledger för pågående plan: `.superpowers/sdd/<plan-namn>/progress.md` (git-ignorerad).
