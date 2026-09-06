# Ljust läge — design

Status: godkänd design, ej påbörjad implementation.
Datum: 2026-09-06.

## Problemet

Appen skickar redan in både `theme: dykLightTheme()` och `darkTheme:
dykDarkTheme()` till `MaterialApp`, och 22 ställen frågar korrekt efter
`Theme.of(context).brightness`. Ljusläget är alltså inte oimplementerat — det
är halvimplementerat, vilket är sämre än antingen ytterlighet, för det ser ut
som en bugg i stället för ett val.

Grundorsaken är att `_base()` i `lib/theme/dyk_theme.dart` nästan är tomt: den
sätter bakgrundsfärg, ett färgschema och en knappstil, men ingen `textTheme`,
`appBarTheme`, `cardTheme` eller `iconTheme`. Eftersom temat inte säger något
om text och ytor har varje skärm fått hitta på själv, och det de hittade på
var mörkt.

Mätning 2026-09-06: 195 hårdkodade `Colors.white` i 38 filer under
`lib/screens/` och `lib/widgets/`. 121 av dem ligger i filer som hårdkodar
mörk bakgrund (`backgroundColor: PassimColors.ink`, `DykColors.black` eller
`Colors.black`), 74 i övriga filer. Den gränsen är grov: bland de 74 finns
`photo_pin.dart`, `mini_player.dart` och `pickpocket_banner.dart`, där vitt är
korrekt eftersom innehållet ligger över foto.

Det är kärnan i varför arbetet är dyrt: **det går inte att se på en
`Colors.white` varför den är vit.** Är den vit för att ytan alltid är mörk,
eller vit för att någon antog mörkt läge? Den frågan går inte att besvara med
sökning, bara genom att läsa varje ställe.

## Beslut

Ljust läge ska gälla **hela** appen, inte bara kromet. Användaren väljer i
Inställningar mellan System, Ljust och Mörkt, och valet sparas.

## Arkitektur

### Temavalet

Appen har redan exakt det mönster som behövs. `I18n` i `lib/i18n/i18n.dart` är
en `ChangeNotifier`-singleton som läser och skriver `SharedPreferences`, och
`MaterialApp` lyssnar på den genom en `AnimatedBuilder` i `main.dart`.

Temavalet blir en kopia av det mönstret, inte en ny uppfinning — nästa person
som läser koden ska känna igen sig:

- `ThemePrefs` (ny fil `lib/theme/theme_prefs.dart`), en `ChangeNotifier`-
  singleton med ett `ThemeMode`, nyckeln `app_theme` i `SharedPreferences`.
- Laddas i samma svep som språket vid start i `main.dart`.
- `MaterialApp` får `themeMode: ThemePrefs.instance.mode`, och den befintliga
  `AnimatedBuilder` utökas till att lyssna på båda (`Listenable.merge`).
- Inställningsskärmen får en väljare byggd som språkväljaren bredvid.

Standardvärde är `ThemeMode.system`, så befintliga användare märker ingen
förändring förrän de aktivt väljer.

### Färgkontraktet

Två delar, som tillsammans gör ett annars ogenomträngligt jobb mekaniskt.

**Temat fylls ut.** `_base()` får `textTheme`, `appBarTheme`, `cardTheme`,
`iconTheme` och `dividerTheme`, så att vanlig text och vanliga ytor blir rätt
utan att skärmen säger något. Det är den enda vägen som gör att framtida
skärmar blir rätt av sig själva.

**En ny semantisk roll.** `PassimColors.onPhoto` — vitt, men med ett namn som
säger varför. Regeln blir:

> Varje `Colors.white` ska antingen **tas bort**, så att färgen ärvs från
> temat, eller bytas mot **`onPhoto`** om den ligger över foto, scrim eller
> amber.

Poängen är mätbarheten: när sökningen efter `Colors.white` ger noll träffar i
en migrerad fil har varje ställe i den filen passerat ett beslut. Utan den
regeln finns inget sätt att veta när man är klar.

`Colors.black` behandlas likadant där det används som textfärg. Där det är en
scrim eller skugga (`withValues(alpha: …)`) lämnas det.

### Assets

Alla tre nya assets finns redan i `design/`.

| Från | Till | Anmärkning |
|---|---|---|
| `design/Passim_logo_bluetext.png` | `assets/images/passim_logo_light.png` | 1983×793, proportion 2,50 mot den mörkas 2,55 — rakt utbyte utan layoutändring |
| `design/Background.png` | `assets/images/landing_background_light.jpg` | 853×1844, snittfärg (230, 226, 215), ligger nära `sand` #F4F1E8 |

`PassimLogo` väljer variant på temat, så de fem användningsställena
(`app_shell`, `auth_screen`, `welcome_screen`, `paused_screen`,
`splash_screen`) inte behöver veta något.

`PassimBackground` och `passimScrim` får ljusa motsvarigheter, där scrimen går
åt andra hållet: ljus dimma över bilden i stället för mörk.

### Glasmenyn

`PassimNavBar` behåller sin konstruktion — samma blur, samma radie 26, samma
bärnstenspiller på aktiv flik. Det som vänds är polariteten: ytan tonas med
`sand` i stället för `ink`, kanten blir en mörk hårfin linje i stället för
vit, och ikonfärgen för inaktiv flik blir mörk i stället för `Colors.white70`.
Skuggan behålls men mildras — en tung svart skugga under en ljus meny ser
smutsig ut.

### Kartan

Tre skärmar hårdkodar `MapboxStyles.DARK` och måste växla:
`active_tour_screen.dart:1445`, `navigate_screen.dart:296`,
`pickpocket_map_screen.dart:187`.

De ska använda samma villkorliga uttryck som `nearby_tab.dart:807` redan gör.
`map_screen.dart:101` kör redan `MAPBOX_STREETS` och är ljus i båda lägena —
den bör också växla, så att mörkt läge blir konsekvent.

Mapbox-lagren tar råa ARGB-heltal (`PassimColors.inkArgb`, `whiteArgb`), och
de valen måste också växla med temat, annars blir linjer och etiketter
osynliga i det ena läget.

### Splash-skärmen

Loggan innehåller redan pinnen: en mätning band för band visar de fyra
översta banden som ~200 px breda och centrerade (pinnen), och de två nedersta
som 950 px (wordmarken). Den nuvarande splash-animationen släpper därför ner
en pinne ovanför en logga som redan har en pinne — två pinnar syns på enheten.

Åtgärd: en wordmark-variant utan pinne (`passim_wordmark.png` respektive
`_light`), beskuren ur befintlig logga, används på splashen så att den
fallande pinnen är den enda pinnen. Splashen byter dessutom logga och
bakgrund med temat.

## Ordning

De 74 vita i temamedvetna filer först — det är där Jose faktiskt märker
skillnaden — sedan de 121 i de hårdkodat mörka filerna, som är det tyngre
jobbet eftersom varje skärm måste få en ljus identitet den aldrig haft.

1. `ThemePrefs` + inställningsväljaren + utökat `_base()`. Efter den här
   etappen går det att växla läge i appen, och kromet ser rätt ut.
2. Assets: loggan, bakgrunden, wordmarken, splashens dubbla pinne.
3. Glasmenyn och kartorna.
4. Temamedvetna skärmar, en i taget.
5. Hårdkodat mörka skärmar, en i taget. Störst risk och störst arbete.

Det går att bygga och titta på enhet efter varje etapp.

## Testning

Ett widgettest som renderar varje skärm i båda lägena och mäter kontrast mot
bakgrunden vore det grundliga, men det är dyrt att bygga rätt och skört mot
layoutändringar.

I stället: ett test som failar om `Colors.white` eller `Colors.black` som
textfärg återkommer i en fil som redan migrerats, med en explicit lista över
migrerade filer som växer etapp för etapp. Det bevakar exakt den regel vi
infört, och den går inte att råka bryta.

Utöver det: befintliga 53 tester ska fortsätta passera, och
`logo_centering_test.dart` ska köras i båda lägena eftersom `PassimLogo` nu
väljer asset.

## Risker

Den nya blå loggan är inte optiskt centrerad på samma sätt som den mörka. Den
mörka har 49 px högerpadding inbakad, tillagd 2026-09 för att kompensera för
att wordmarkens tyngdpunkt ligger till höger om dess bbox. Mätning av den blå:
bbox-mitt 1034,5 mot bildmitt 991,5 — innehållet sitter 43 px till höger.
Optisk mitt är 1001,4, alltså 10 px höger om bildmitt, vilket vid 34 px
visningshöjd blir under en pixel. Sannolikt oproblematiskt, men ska
kontrolleras på enhet, och `logo_centering_test.dart` mäter widgetens mitt och
inte pixlarnas — den fångar det inte.

De hårdkodat mörka skärmarna (hotspot-detalj, turdetalj, aktiv tur,
stoppdetalj) är immersiva innehållsskärmar med foto och video. Att göra dem
ljusa är inte bara ett färgbyte utan ett designbeslut per skärm, och de kan
behöva ny scrim-logik över bilder. Det är den etapp som mest sannolikt
behöver en runda med Jose innan den låses.
