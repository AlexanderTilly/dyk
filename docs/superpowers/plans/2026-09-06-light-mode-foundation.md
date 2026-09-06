# Light Mode Foundation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the user able to choose System / Light / Dark in Settings, and make the app's shared furniture — theme, logo, background, scrim, navigation bar, maps, splash — correct in both modes.

**Architecture:** The theme preference copies the existing `I18n` singleton pattern exactly (ChangeNotifier + SharedPreferences + AnimatedBuilder in `main.dart`). `_base()` in the theme is filled out so that ordinary text and surfaces inherit correct colour instead of each screen inventing its own. A single new constant, `PassimColors.onPhoto`, gives deliberate whites a name that states why they are white — that is what makes the later per-screen migration mechanical rather than guesswork.

**Tech Stack:** Flutter 3.44.1, Material 3, shared_preferences, mapbox_maps_flutter 2.24.3 (pinned — 2.29.0 fails Kotlin compile), Pillow (Python) for the one-off asset preparation.

**Spec:** `docs/superpowers/specs/2026-09-06-light-mode-design.md`

## Scope

This plan covers stages 1–3 of the spec: the preference, the theme, the assets, the navigation bar, the maps and the splash screen. It delivers working, testable software on its own — after it, the user can switch modes and the app's chrome is correct.

Stages 4–5 of the spec — migrating the 195 hardcoded `Colors.white` across 38 screen files — are deliberately **not** in this plan. They are a separate, much larger body of work that depends on the contract this plan establishes, and they need a per-screen design pass with Jose. They get their own plan.

## Global Constraints

- Brand palette values are fixed and must be copied verbatim: brand `#FFC21A`, ink `#071A2F`, surface `#223247`, sand `#F4F1E8`, green `#22C55E`.
- `mapbox_maps_flutter` stays pinned at `2.24.3`. Do not upgrade.
- New user-facing strings must be added to **all four** languages in `lib/i18n/i18n.dart`: `en`, `es`, `ca`, `de`.
- Default theme mode is `ThemeMode.system`, so existing users see no change until they choose.
- `flutter analyze` must report no issues before each commit.
- All 53 existing tests must keep passing.
- Commit messages end with `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.

## File Structure

| File | Responsibility |
|---|---|
| `lib/theme/theme_prefs.dart` (new) | Holds the chosen `ThemeMode`, persists it, notifies listeners. Nothing else. |
| `lib/theme/dyk_theme.dart` (modify) | The palette plus the two `ThemeData` objects. Gains `onPhoto` and the filled-out `_base()`. |
| `lib/widgets/passim_background.dart` (modify) | Artwork, scrim and wordmark — the three things that need a light variant of an asset. |
| `lib/widgets/passim_nav_bar.dart` (modify) | The floating glass bar; gains light polarity. |
| `lib/screens/splash_screen.dart` (modify) | Theme-aware, and stops drawing two pins. |
| `lib/main.dart` (modify) | Loads the preference and passes `themeMode` to `MaterialApp`. |
| `lib/screens/settings_screen.dart` (modify) | The picker. |
| `lib/i18n/i18n.dart` (modify) | Four new keys × four languages. |
| `test/theme/theme_prefs_test.dart` (new) | Preference load/save/default behaviour. |
| `test/widgets/passim_logo_test.dart` (new) | Asset selection follows brightness. |
| `test/theme/theme_contract_test.dart` (new) | The regression guard for the colour rule. |

---

### Task 1: The theme preference

**Files:**
- Create: `lib/theme/theme_prefs.dart`
- Create: `test/theme/theme_prefs_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `ThemePrefs.instance` (a `ChangeNotifier`), `ThemePrefs.instance.mode` → `ThemeMode`, `Future<void> load(SharedPreferences prefs)`, `Future<void> setMode(ThemeMode mode)`. Tasks 2 and 6 depend on these exact names.

- [ ] **Step 1: Write the failing test**

Create `test/theme/theme_prefs_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:palma_app/theme/theme_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to system when nothing is stored', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await ThemePrefs.instance.load(prefs);
    expect(ThemePrefs.instance.mode, ThemeMode.system);
  });

  test('restores a stored choice', () async {
    SharedPreferences.setMockInitialValues({'app_theme': 'light'});
    final prefs = await SharedPreferences.getInstance();
    await ThemePrefs.instance.load(prefs);
    expect(ThemePrefs.instance.mode, ThemeMode.light);
  });

  test('falls back to system on an unrecognised stored value', () async {
    SharedPreferences.setMockInitialValues({'app_theme': 'sepia'});
    final prefs = await SharedPreferences.getInstance();
    await ThemePrefs.instance.load(prefs);
    expect(ThemePrefs.instance.mode, ThemeMode.system);
  });

  test('setMode persists and notifies', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await ThemePrefs.instance.load(prefs);

    var notified = 0;
    void listener() => notified++;
    ThemePrefs.instance.addListener(listener);
    addTearDown(() => ThemePrefs.instance.removeListener(listener));

    await ThemePrefs.instance.setMode(ThemeMode.dark);

    expect(ThemePrefs.instance.mode, ThemeMode.dark);
    expect(notified, 1);
    expect(prefs.getString('app_theme'), 'dark');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/theme/theme_prefs_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'palma_app' ... theme_prefs.dart` (the file does not exist yet).

- [ ] **Step 3: Write the implementation**

Create `lib/theme/theme_prefs.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which theme the user picked. Deliberately a copy of [I18n]'s shape —
/// singleton ChangeNotifier over SharedPreferences, listened to by the
/// MaterialApp — so there is one pattern in this app for "a setting that
/// rebuilds everything", not two.
class ThemePrefs extends ChangeNotifier {
  static final ThemePrefs instance = ThemePrefs._();
  ThemePrefs._();

  static const _key = 'app_theme';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  /// Stored as a short string rather than the enum index: an index would
  /// silently change meaning if ThemeMode ever gained a value.
  static ThemeMode _parse(String? raw) => switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static String _encode(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };

  Future<void> load(SharedPreferences prefs) async {
    _mode = _parse(prefs.getString(_key));
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _encode(mode));
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/theme/theme_prefs_test.dart`
Expected: PASS, 4 tests.

Note: `load()` calls `notifyListeners()`, so the first test's expectation of exactly 1 notification in the fourth test holds only because the listener is attached after `load()`. Keep that ordering.

- [ ] **Step 5: Commit**

```bash
git add lib/theme/theme_prefs.dart test/theme/theme_prefs_test.dart
git commit -m "feat(theme): remember the user's light/dark choice

Same shape as I18n — singleton ChangeNotifier over SharedPreferences —
so there is one pattern in this app for a setting that rebuilds the tree.
Stored as a string, not the enum index, which would silently change
meaning if ThemeMode gained a value.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: Wire the preference into MaterialApp

**Files:**
- Modify: `lib/main.dart:72-74` (load) and `lib/main.dart:548-560` (MaterialApp)

**Interfaces:**
- Consumes: `ThemePrefs.instance`, `.load()`, `.mode` from Task 1.
- Produces: a `MaterialApp` that rebuilds on either language or theme change. Task 3 relies on `Theme.of(context).brightness` being correct app-wide.

- [ ] **Step 1: Load the preference at startup**

In `lib/main.dart`, find:

```dart
  final prefs = await SharedPreferences.getInstance();
  await I18n.instance.load(prefs);
```

Replace with:

```dart
  final prefs = await SharedPreferences.getInstance();
  await I18n.instance.load(prefs);
  await ThemePrefs.instance.load(prefs);
```

Add the import alongside the other local imports:

```dart
import 'theme/theme_prefs.dart';
```

- [ ] **Step 2: Listen to both settings and pass themeMode**

In `lib/main.dart`, find the `build` method returning `AnimatedBuilder(animation: I18n.instance, ...)` and replace the whole return with:

```dart
    // Rebuild the whole app when the language or the theme changes (home is
    // created inside the builder so every screen picks up both).
    return AnimatedBuilder(
      animation: Listenable.merge([I18n.instance, ThemePrefs.instance]),
      builder: (context, _) => MaterialApp(
        navigatorKey: _navKey,
        title: 'Passim',
        debugShowCheckedModeBanner: false,
        theme: dykLightTheme(),
        darkTheme: dykDarkTheme(),
        themeMode: ThemePrefs.instance.mode,
        builder: (context, child) =>
            WithForegroundTask(child: child ?? const SizedBox.shrink()),
        home: _buildHome(),
      ),
    );
```

- [ ] **Step 3: Verify it analyses and builds**

Run: `flutter analyze lib/main.dart`
Expected: `No issues found!`

- [ ] **Step 4: Run the full suite**

Run: `flutter test`
Expected: PASS, 57 tests (53 existing + 4 from Task 1).

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart
git commit -m "feat(theme): apply the saved theme choice app-wide

The MaterialApp already rebuilt on language change; it now listens to
both notifiers through Listenable.merge, so a theme change propagates
the same way rather than needing a restart.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: Fill out the theme and add the onPhoto role

**Files:**
- Modify: `lib/theme/dyk_theme.dart:9-31` (palette) and `lib/theme/dyk_theme.dart:44-68` (`_base`)
- Create: `test/theme/theme_contract_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `PassimColors.onPhoto` (a `Color`), and a `ThemeData` whose `textTheme.bodyMedium.color`, `appBarTheme`, `cardTheme`, `iconTheme` and `dividerTheme` are set for both brightnesses. Tasks 4, 5, 6 and 7 rely on `onPhoto` existing.

- [ ] **Step 1: Write the failing test**

Create `test/theme/theme_contract_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palma_app/theme/dyk_theme.dart';

/// The theme is the app's colour contract. Screens that state no colour must
/// get a readable one from here — that is what lets the screen migration
/// delete colours rather than make every one of them conditional.
void main() {
  test('body text is ink on light and near-white on dark', () {
    expect(dykLightTheme().textTheme.bodyMedium!.color, PassimColors.ink);
    expect(dykDarkTheme().textTheme.bodyMedium!.color, PassimColors.onPhoto);
  });

  test('app bar follows the mode rather than staying navy', () {
    expect(dykLightTheme().appBarTheme.backgroundColor, PassimColors.sand);
    expect(dykLightTheme().appBarTheme.foregroundColor, PassimColors.ink);
    expect(dykDarkTheme().appBarTheme.backgroundColor, PassimColors.ink);
    expect(dykDarkTheme().appBarTheme.foregroundColor, PassimColors.onPhoto);
  });

  test('cards are white on light and raised navy on dark', () {
    expect(dykLightTheme().cardTheme.color, Colors.white);
    expect(dykDarkTheme().cardTheme.color, PassimColors.surface);
  });

  test('icons follow the mode', () {
    expect(dykLightTheme().iconTheme.color, PassimColors.ink);
    expect(dykDarkTheme().iconTheme.color, PassimColors.onPhoto);
  });

  test('onPhoto is white — it is white text, just named for its reason', () {
    expect(PassimColors.onPhoto, Colors.white);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/theme/theme_contract_test.dart`
Expected: FAIL — `The getter 'onPhoto' isn't defined for the class 'PassimColors'`.

- [ ] **Step 3: Add the role to the palette**

In `lib/theme/dyk_theme.dart`, inside `class PassimColors`, after the `green` declaration, add:

```dart
  /// White that is white *on purpose*: text and icons sitting over a photo, a
  /// scrim, or the amber brand colour, where the surface is dark regardless of
  /// the user's theme.
  ///
  /// The point is the name. A bare `Colors.white` cannot tell you whether it
  /// is deliberate or a leftover from when this app was dark-only, and that
  /// question cannot be answered by searching — only by reading every site.
  /// Anything still literal is therefore unreviewed.
  static const onPhoto = Colors.white;
```

- [ ] **Step 4: Fill out `_base()`**

In `lib/theme/dyk_theme.dart`, replace the whole `_base` function with:

```dart
ThemeData _base(Brightness b) {
  final dark = b == Brightness.dark;

  // The one place that answers "what colour is ordinary text/iconography".
  // Before this existed every screen answered for itself, and what they all
  // answered was "white" — which is exactly why light mode was broken.
  final onSurface = dark ? PassimColors.onPhoto : PassimColors.ink;
  final surface = dark ? PassimColors.surface : Colors.white;
  final background = dark ? PassimColors.ink : PassimColors.sand;

  return ThemeData(
    useMaterial3: true,
    brightness: b,
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: PassimColors.brand,
      brightness: b,
      primary: PassimColors.brand,
      onPrimary: PassimColors.ink,
      surface: surface,
      onSurface: onSurface,
    ),
    textTheme: Typography.material2021(platform: TargetPlatform.android)
        .black
        .apply(bodyColor: onSurface, displayColor: onSurface),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    iconTheme: IconThemeData(color: onSurface),
    dividerTheme: DividerThemeData(
      color: onSurface.withValues(alpha: 0.12),
      thickness: 1,
    ),
    listTileTheme: ListTileThemeData(
      textColor: onSurface,
      iconColor: onSurface,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: PassimColors.brand,
        foregroundColor: PassimColors.ink,
        textStyle: const TextStyle(
            fontWeight: FontWeight.w800, letterSpacing: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      ),
    ),
  );
}
```

Note: `Typography.material2021(...).black` is the *dark-on-light* text set; `.apply()` then overrides the colours for both modes, so the choice of `.black` here is only a starting point for sizes and weights.

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/theme/theme_contract_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 6: Run the full suite and analyse**

Run: `flutter test && flutter analyze lib/theme/dyk_theme.dart`
Expected: all tests PASS; `No issues found!`

If existing tests fail here, that is real information: it means a screen depended on the theme *not* specifying a colour. Fix the screen, not the theme.

- [ ] **Step 7: Commit**

```bash
git add lib/theme/dyk_theme.dart test/theme/theme_contract_test.dart
git commit -m "feat(theme): give the theme an actual colour contract

_base() set a background, a colour scheme and a button style and nothing
else — no textTheme, appBarTheme, cardTheme or iconTheme. That is the root
cause of light mode: with nothing to inherit, every screen invented its
own colours, and what they invented was dark.

Also adds PassimColors.onPhoto: white, but named for its reason, so a
deliberate white over a photo is distinguishable from a leftover.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: Prepare the light assets

**Files:**
- Create: `assets/images/passim_logo_light.png` (from `design/Passim_logo_bluetext.png`)
- Create: `assets/images/passim_wordmark.png` and `assets/images/passim_wordmark_light.png` (cropped)
- Create: `assets/images/landing_background_light.jpg` (from `design/Background.png`)
- Create: `tool/prepare_light_assets.py`

**Interfaces:**
- Consumes: nothing.
- Produces: four asset paths under `assets/images/`, referenced by Tasks 5 and 7.

The wordmark crops exist because the logo already contains the pin. Measured band-by-band on 2026-09-06: the dark logo (1179×462) has an empty row band at y 284–305, the light logo (1983×793) at y 506–525. Everything above is the pin, everything below is "PASSIM". The splash animation drops its own pin, so it needs the part below.

- [ ] **Step 1: Write the preparation script**

Create `tool/prepare_light_assets.py`:

```python
"""One-off preparation of the light-mode assets.

Kept in the repo rather than run ad hoc so the crops are reproducible: the
wordmark files are derived, and if the logo is ever redrawn they have to be
regenerated the same way.
"""
from PIL import Image

SRC_DARK = "assets/images/passim_logo.png"
SRC_LIGHT = "design/Passim_logo_bluetext.png"
SRC_BG = "design/Background.png"


def split_row(path):
    """The empty band between the pin and the wordmark, as a y coordinate."""
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    px = im.load()
    rows = [any(px[x, y][3] > 10 for x in range(0, w, 2)) for y in range(h)]
    gaps, start = [], None
    for y, filled in enumerate(rows):
        if not filled and start is None:
            start = y
        if filled and start is not None:
            if y - start > 3:
                gaps.append((start, y))
            start = None
    # The gap that separates the pin from the wordmark is the last one that
    # still has content below it.
    top, bottom = gaps[-1]
    return (top + bottom) // 2


def crop_wordmark(src, dest):
    im = Image.open(src).convert("RGBA")
    y = split_row(src)
    im.crop((0, y, im.width, im.height)).save(dest)
    print("%s -> %s (klipp vid y=%d)" % (src, dest, y))


# Full logo, blue text, for light backgrounds.
Image.open(SRC_LIGHT).convert("RGBA").save("assets/images/passim_logo_light.png")
print("%s -> assets/images/passim_logo_light.png" % SRC_LIGHT)

crop_wordmark(SRC_DARK, "assets/images/passim_wordmark.png")
crop_wordmark(SRC_LIGHT, "assets/images/passim_wordmark_light.png")

# The artwork. JPEG to match landing_background.jpg and keep the APK down;
# it is a photographic backdrop with no transparency.
bg = Image.open(SRC_BG).convert("RGB")
bg.save("assets/images/landing_background_light.jpg", quality=88, optimize=True)
print("%s -> assets/images/landing_background_light.jpg %s" % (SRC_BG, bg.size))
```

- [ ] **Step 2: Run it**

Run: `python tool/prepare_light_assets.py`
Expected output shows the two crops at y=294 and y=515, and the background written.

- [ ] **Step 3: Verify the results**

Run:

```bash
python -c "
from PIL import Image
for p in ['assets/images/passim_logo_light.png','assets/images/passim_wordmark.png','assets/images/passim_wordmark_light.png','assets/images/landing_background_light.jpg']:
    im = Image.open(p); print(p, im.size, im.mode)
"
```

Expected: `passim_wordmark.png` is 1179×168 and `passim_wordmark_light.png` is 1983×278 — both much wider than tall, confirming the pin was removed. If either is still roughly 2.5:1, the crop failed and the split row was wrong.

- [ ] **Step 4: Check the asset declaration**

`pubspec.yaml` declares the `assets/images/` directory rather than individual files, so no change is needed. Confirm with:

```bash
grep -A 4 "assets:" pubspec.yaml
```

If it lists individual files instead, add the four new paths.

- [ ] **Step 5: Commit**

```bash
git add tool/prepare_light_assets.py assets/images/passim_logo_light.png assets/images/passim_wordmark.png assets/images/passim_wordmark_light.png assets/images/landing_background_light.jpg
git commit -m "feat(assets): light artwork, blue-text logo, and wordmark crops

The wordmark crops exist because the logo already contains the pin — the
splash animation drops a second one on top of it. Measuring band by band
puts the seam at y=294 on the dark logo and y=515 on the light one.

The crop is scripted rather than done by hand so it is reproducible if the
logo is redrawn.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: Make the logo, artwork and scrim theme-aware

**Files:**
- Modify: `lib/widgets/passim_background.dart` (whole file)
- Modify: the eight `passimScrim()` call sites listed below
- Create: `test/widgets/passim_logo_test.dart`

**Interfaces:**
- Consumes: `PassimColors.onPhoto` (Task 3), the asset paths (Task 4).
- Produces: `PassimLogo({double height, bool wordmarkOnly})`, `PassimBackground({Widget child, Scrim scrim})`, and a **changed signature** `passimScrim(BuildContext context, {Scrim strength})`. Task 7 uses `wordmarkOnly: true`.

`passimScrim` gains a `BuildContext` because it is a top-level function with no other way to know the brightness. All eight call sites are inside `build` methods, so context is available at each.

- [ ] **Step 1: Write the failing test**

Create `test/widgets/passim_logo_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palma_app/theme/dyk_theme.dart';
import 'package:palma_app/widgets/passim_background.dart';

/// The dark wordmark is cream-coloured and vanishes on sand, so the asset has
/// to follow the theme rather than the screen remembering to ask.
void main() {
  String assetOf(WidgetTester tester) {
    final image = tester.widget<Image>(find.byType(Image));
    return (image.image as AssetImage).assetName;
  }

  Future<void> pump(WidgetTester tester, Brightness b,
      {bool wordmarkOnly = false}) async {
    await tester.pumpWidget(MaterialApp(
      theme: b == Brightness.dark ? dykDarkTheme() : dykLightTheme(),
      home: Scaffold(body: PassimLogo(wordmarkOnly: wordmarkOnly)),
    ));
  }

  testWidgets('uses the cream logo on dark', (tester) async {
    await pump(tester, Brightness.dark);
    expect(assetOf(tester), 'assets/images/passim_logo.png');
  });

  testWidgets('uses the blue logo on light', (tester) async {
    await pump(tester, Brightness.light);
    expect(assetOf(tester), 'assets/images/passim_logo_light.png');
  });

  testWidgets('wordmarkOnly drops the pin, per theme', (tester) async {
    await pump(tester, Brightness.dark, wordmarkOnly: true);
    expect(assetOf(tester), 'assets/images/passim_wordmark.png');
    await pump(tester, Brightness.light, wordmarkOnly: true);
    expect(assetOf(tester), 'assets/images/passim_wordmark_light.png');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/widgets/passim_logo_test.dart`
Expected: FAIL — `No named parameter with the name 'wordmarkOnly'`.

- [ ] **Step 3: Rewrite the widget file**

Replace the whole of `lib/widgets/passim_background.dart` with:

```dart
import 'package:flutter/material.dart';

import '../theme/dyk_theme.dart';

/// The branded backdrop: the Passim artwork under a scrim.
///
/// The artwork is bright enough on its own to swallow text and the wordmark,
/// so every screen puts the same fade over it — and the fade runs towards the
/// theme's own background colour, so the polarity flips with the mode instead
/// of leaving a navy haze over a light app.
class PassimBackground extends StatelessWidget {
  final Widget child;

  /// How heavy the scrim is. [Scrim.light] keeps the artwork legible on
  /// splash and onboarding; [Scrim.heavy] is for screens full of text.
  final Scrim scrim;

  const PassimBackground({
    super.key,
    required this.child,
    this.scrim = Scrim.heavy,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(passimArtwork(context)),
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
      ),
      child: DecoratedBox(
        decoration: passimScrim(context, strength: scrim),
        child: child,
      ),
    );
  }
}

enum Scrim { light, heavy }

/// Which artwork file matches the current theme.
String passimArtwork(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? 'assets/images/landing_background.jpg'
        : 'assets/images/landing_background_light.jpg';

/// The wordmark.
///
/// The asset follows the theme rather than the caller: the cream logo is
/// invisible on sand, and there are five call sites that would each have to
/// remember. [wordmarkOnly] drops the pin — the full logo already contains
/// one, so anything drawing its own pin must use this.
class PassimLogo extends StatelessWidget {
  final double height;
  final bool wordmarkOnly;

  const PassimLogo({super.key, this.height = 40, this.wordmarkOnly = false});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final asset = switch ((wordmarkOnly, dark)) {
      (true, true) => 'assets/images/passim_wordmark.png',
      (true, false) => 'assets/images/passim_wordmark_light.png',
      (false, true) => 'assets/images/passim_logo.png',
      (false, false) => 'assets/images/passim_logo_light.png',
    };
    return Image.asset(asset, height: height, fit: BoxFit.contain);
  }
}

/// The scrim as a decoration, for screens that already own their background
/// container.
///
/// Takes a context because it has no other way to know the brightness, and a
/// scrim that does not flip is exactly the navy haze this work is removing.
BoxDecoration passimScrim(BuildContext context,
    {Scrim strength = Scrim.heavy}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final (top, bottom) = switch (strength) {
    Scrim.light => (0.05, 0.30),
    // Light mode needs a heavier veil: sand over a bright photo separates
    // less than navy does, so the same alpha would leave text sitting on
    // texture.
    Scrim.heavy => dark ? (0.25, 0.62) : (0.45, 0.80),
  };
  final base = dark ? PassimColors.ink : PassimColors.sand;
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [base.withValues(alpha: top), base.withValues(alpha: bottom)],
    ),
  );
}
```

- [ ] **Step 4: Update the eight call sites**

Each currently reads `dark ? passimScrim() : BoxDecoration(color: ...)` or a bare `passimScrim()`. The conditional collapses, because the function now decides:

| File | Line | Change |
|---|---|---|
| `lib/screens/app_shell.dart` | 299 | replace the `dark ? passimScrim() : BoxDecoration(...)` expression with `passimScrim(context)` |
| `lib/screens/app_shell.dart` | 424 | same |
| `lib/screens/notification_center_screen.dart` | 107 | same |
| `lib/screens/settings_screen.dart` | 173 | same |
| `lib/screens/support_screen.dart` | 90 | same |
| `lib/screens/premium_screen.dart` | 57 | `passimScrim()` → `passimScrim(context)` |
| `lib/screens/welcome_city_screen.dart` | 46 | `passimScrim()` → `passimScrim(context)` |
| `lib/screens/splash_screen.dart` | 115 | `passimScrim(strength: Scrim.light)` → `passimScrim(context, strength: Scrim.light)` |

Where removing the ternary leaves an unused `final dark = ...` local, delete it — `flutter analyze` will name the file and line.

- [ ] **Step 5: Run the tests and analyse**

Run: `flutter test && flutter analyze`
Expected: all tests PASS (60 now); `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/passim_background.dart lib/screens test/widgets/passim_logo_test.dart
git commit -m "feat(ui): logo, artwork and scrim follow the theme

The cream wordmark is invisible on sand, and five call sites would each
have had to remember — so the asset choice moves into PassimLogo.

passimScrim now takes a context. It is a top-level function with no other
way to know the brightness, and a scrim that cannot flip is exactly the
navy haze over a light app that this work exists to remove. The light
scrim is heavier: sand over a bright photo separates less than navy does.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: The Settings picker

**Files:**
- Modify: `lib/i18n/i18n.dart` (four keys × four languages)
- Modify: `lib/screens/settings_screen.dart` — new section before the Language section at line 282

**Interfaces:**
- Consumes: `ThemePrefs.instance` (Task 1), `tr()` from i18n.
- Produces: nothing other tasks depend on.

- [ ] **Step 1: Add the strings**

In `lib/i18n/i18n.dart`, next to each existing `'language':` entry, add four keys in the matching language:

```dart
// en (near line 136)
    'appearance': 'Appearance',
    'theme_system': 'System',
    'theme_light': 'Light',
    'theme_dark': 'Dark',

// es (near line 379)
    'appearance': 'Apariencia',
    'theme_system': 'Sistema',
    'theme_light': 'Claro',
    'theme_dark': 'Oscuro',

// ca (near line 619)
    'appearance': 'Aparença',
    'theme_system': 'Sistema',
    'theme_light': 'Clar',
    'theme_dark': 'Fosc',

// de (near line 859)
    'appearance': 'Darstellung',
    'theme_system': 'System',
    'theme_light': 'Hell',
    'theme_dark': 'Dunkel',
```

- [ ] **Step 2: Add the section**

In `lib/screens/settings_screen.dart`, immediately before the `// --- Language ---` comment, insert:

```dart
              // --- Appearance ---
              _section(tr('appearance'), [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (mode, label) in const [
                      (ThemeMode.system, 'theme_system'),
                      (ThemeMode.light, 'theme_light'),
                      (ThemeMode.dark, 'theme_dark'),
                    ])
                      ChoiceChip(
                        selected: ThemePrefs.instance.mode == mode,
                        selectedColor: DykColors.yellow,
                        label: Text(tr(label)),
                        onSelected: (_) async {
                          await ThemePrefs.instance.setMode(mode);
                          if (mounted) setState(() {});
                        },
                      ),
                  ],
                ),
              ]),
```

Add the import:

```dart
import '../theme/theme_prefs.dart';
```

- [ ] **Step 3: Analyse**

Run: `flutter analyze lib/screens/settings_screen.dart lib/i18n/i18n.dart`
Expected: `No issues found!`

- [ ] **Step 4: Verify on a device or emulator**

Run: `flutter run`

Open Settings, switch between the three chips. Expected: the whole app changes immediately without a restart, and the choice survives killing and reopening the app. This is the first point where the feature is visible; check it before moving on.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/settings_screen.dart lib/i18n/i18n.dart
git commit -m "feat(settings): let the user choose System, Light or Dark

Built as the language picker beside it, in all four languages.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 7: Splash screen — one pin, both themes

**Files:**
- Modify: `lib/screens/splash_screen.dart:100-180`

**Interfaces:**
- Consumes: `PassimLogo(wordmarkOnly: true)` (Task 5), `passimArtwork(context)` and `passimScrim(context, ...)` (Task 5).
- Produces: nothing other tasks depend on.

The falling-pin animation currently sits above the full logo, which already contains a pin — two pins appear on the device. The fix is the cropped wordmark from Task 4.

- [ ] **Step 1: Swap the artwork for the theme-aware one**

In the `build` method, replace:

```dart
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/landing_background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
```

with:

```dart
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(passimArtwork(context)),
            fit: BoxFit.cover,
          ),
        ),
```

- [ ] **Step 2: Use the wordmark instead of the full logo**

Replace the `Image.asset('assets/images/passim_logo.png', height: 116)` at the bottom of the column with:

```dart
                  child: const PassimLogo(height: 44, wordmarkOnly: true),
```

The height drops from 116 to 44 because the cropped asset is the wordmark alone — 1179×168 rather than 1179×462 — so the same visual size needs roughly a third of the height.

- [ ] **Step 3: Make the ripple readable on light**

In `_RipplePainter`, the amber rings sit on a light background in light mode and lose contrast. Give the painter the brightness and darken the ring there. Change the constructor and field:

```dart
  final double impact;
  final double? idle;
  final bool dark;

  _RipplePainter({required this.impact, this.idle, required this.dark});
```

In `_ring`, replace the colour line with:

```dart
        ..color = (dark ? PassimColors.brand : PassimColors.ink)
            .withValues(alpha: opacity),
```

In `shouldRepaint`, add the field:

```dart
  @override
  bool shouldRepaint(_RipplePainter old) =>
      old.impact != impact || old.idle != idle || old.dark != dark;
```

And at the `CustomPaint` call site, pass it:

```dart
                            painter: _RipplePainter(
                              impact: _landRipple.value,
                              idle: _ripple.isAnimating ? _ripple.value : null,
                              dark: Theme.of(context).brightness ==
                                  Brightness.dark,
                            ),
```

- [ ] **Step 4: Analyse and run**

Run: `flutter analyze lib/screens/splash_screen.dart`
Expected: `No issues found!`

Run: `flutter run` and restart the app in both modes.
Expected: exactly one pin falls, lands, and the wordmark rises beneath it. The pin should sit directly above the "PASSIM" wordmark with no second pin inside it.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/splash_screen.dart
git commit -m "fix(splash): one pin, not two, and both themes

The logo asset already contains the pin — measuring it band by band shows
a 200px centred mass above the 950px wordmark — so the drop animation was
landing a second pin on top of the first. Uses the cropped wordmark now.

The ripple also switches to ink on light backgrounds; amber on sand has
almost no contrast.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 8: The navigation bar in light mode

**Files:**
- Modify: `lib/widgets/passim_nav_bar.dart:41-58` and `:96`

**Interfaces:**
- Consumes: `PassimColors.onPhoto` (Task 3).
- Produces: nothing other tasks depend on.

The construction stays — same blur, same radius 26, same amber pill. Only the polarity flips.

- [ ] **Step 1: Flip the surface, border and shadow**

In `PassimNavBar.build`, before the `return`, add:

```dart
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tint = dark ? PassimColors.ink : PassimColors.sand;
```

Replace the `DecoratedBox` decoration with:

```dart
            decoration: BoxDecoration(
              // Translucent so the blur is visible; without any tint the text
              // loses contrast over bright photos.
              color: tint.withValues(alpha: dark ? 0.62 : 0.78),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: dark
                    ? PassimColors.onPhoto.withValues(alpha: 0.10)
                    : PassimColors.ink.withValues(alpha: 0.08),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  // A heavy black shadow under a light bar reads as dirt, so
                  // the light mode gets a much softer one.
                  color: PassimColors.ink
                      .withValues(alpha: dark ? 0.35 : 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
```

The light tint is 0.78 rather than 0.62: sand is closer in luminance to a bright photo than navy is, so it needs more opacity to hold the labels.

- [ ] **Step 2: Flip the inactive item colour**

In `_NavButton.build`, replace the `colour` line with:

```dart
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colour = selected
        ? PassimColors.brand
        : (dark
            ? PassimColors.onPhoto.withValues(alpha: 0.70)
            : PassimColors.ink.withValues(alpha: 0.60));
```

Note: amber on sand is weak for the *selected* label too. Keep amber for the pill fill, but if the selected label proves unreadable on device, the fallback is `PassimColors.ink` for the label with the amber pill behind it. Check before deciding.

- [ ] **Step 3: Analyse and look at it**

Run: `flutter analyze lib/widgets/passim_nav_bar.dart`
Expected: `No issues found!`

Run: `flutter run`, switch to light mode, and move between tabs over both a photo-heavy screen and a plain one.

- [ ] **Step 4: Commit**

```bash
git add lib/widgets/passim_nav_bar.dart
git commit -m "feat(ui): light polarity for the floating nav bar

Same blur, radius and amber pill — only the polarity flips. The light
tint is 0.78 rather than 0.62 because sand sits closer in luminance to a
bright photo than navy does, and the shadow is much softer: a heavy black
shadow under a light bar reads as dirt.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 9: Maps follow the theme

**Files:**
- Modify: `lib/screens/active_tour_screen.dart:1445`
- Modify: `lib/screens/navigate_screen.dart:296`
- Modify: `lib/screens/pickpocket_map_screen.dart:187`
- Modify: `lib/screens/map_screen.dart:101`

**Interfaces:**
- Consumes: nothing new.
- Produces: nothing other tasks depend on.

`nearby_tab.dart:807` already branches correctly and is the pattern to copy. `map_screen.dart` is the mirror-image bug: it is always light, so it is wrong in dark mode.

- [ ] **Step 1: Switch the four style URIs**

In each of the four files, inside the `build` method that contains the `MapWidget`, add near the top if it is not already there:

```dart
    final dark = Theme.of(context).brightness == Brightness.dark;
```

Then replace the style line:

```dart
            styleUri: dark ? MapboxStyles.DARK : MapboxStyles.MAPBOX_STREETS,
```

For `map_screen.dart:101`, the current line is `styleUri: MapboxStyles.MAPBOX_STREETS,` — same replacement.

If the `MapWidget` is built outside a method with a `context` in scope, capture the brightness in the enclosing `build` and pass it down as a field rather than reaching for a global.

- [ ] **Step 2: Audit the raw ARGB layer colours**

Mapbox style layers take ints, not `Color`, so they do not inherit anything. Find them:

```bash
grep -rn "Argb" lib/screens lib/widgets
```

For each hit, decide: a colour drawn **on the map surface** (route lines, labels, halos) must switch with the theme; a colour inside a **pin or marker graphic** that has its own background does not. Where it must switch, replace `PassimColors.inkArgb` with a local:

```dart
    final onMapArgb =
        dark ? PassimColors.whiteArgb : PassimColors.inkArgb;
```

Route casings and text halos usually want the opposite of the line itself — check each on the device rather than assuming.

- [ ] **Step 3: Analyse**

Run: `flutter analyze lib/screens`
Expected: `No issues found!`

- [ ] **Step 4: Verify each map on a device**

Run: `flutter run` in light mode and open, in turn: Nearby, the full map, an active tour, navigation, and the pickpocket map. Expected: every map is light, and route lines and labels are readable on all five. Then repeat in dark mode.

This step cannot be skipped or replaced by a test — Mapbox renders natively and nothing in the widget tree reflects whether a line is visible.

- [ ] **Step 5: Commit**

```bash
git add lib/screens
git commit -m "fix(map): every map follows the theme

Three screens hardcoded MapboxStyles.DARK and map_screen hardcoded the
light one — so the app was wrong in one mode or the other depending on
which map you opened. Nearby already branched; the rest now match it.

Mapbox layers take raw ARGB ints and inherit nothing, so the line and
label colours had to be switched by hand alongside.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 10: Guard the contract

**Files:**
- Modify: `test/theme/theme_contract_test.dart`

**Interfaces:**
- Consumes: everything above.
- Produces: the regression guard the screen-migration plan will extend.

A contrast-measuring widget test over every screen would be the thorough thing, but it is expensive to build correctly and brittle against layout changes. The cheap guard watches the exact rule this work introduced, and cannot be broken by accident.

- [ ] **Step 1: Write the failing test**

Append to `test/theme/theme_contract_test.dart`:

```dart
import 'dart:io';

/// Files that have been through the light-mode migration. A literal white in
/// one of these is a regression: the rule is that every white is either
/// deleted, so the colour is inherited, or named PassimColors.onPhoto so it
/// states why it is deliberate.
///
/// This list grows as screens are migrated. It is what makes an otherwise
/// unmeasurable 195-site job finishable — a file on this list is reviewed.
const migratedFiles = [
  'lib/widgets/passim_background.dart',
  'lib/widgets/passim_nav_bar.dart',
  'lib/screens/splash_screen.dart',
  'lib/theme/dyk_theme.dart',
];

void mainGuard() {
  test('migrated files use onPhoto, never a literal white', () {
    final offenders = <String>[];
    for (final path in migratedFiles) {
      final lines = File(path).readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // The palette itself has to name the literal once.
        if (path.endsWith('dyk_theme.dart') && line.contains('onPhoto =')) {
          continue;
        }
        if (line.contains('Colors.white')) {
          offenders.add('$path:${i + 1}: ${line.trim()}');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'use PassimColors.onPhoto, or delete the colour so the '
            'theme supplies it:\n${offenders.join('\n')}');
  });
}
```

Then call `mainGuard();` as the last line of the existing `void main() { ... }` in that file, and move the `import 'dart:io';` to the top of the file with the other imports.

- [ ] **Step 2: Run it**

Run: `flutter test test/theme/theme_contract_test.dart`
Expected: FAIL, listing the remaining `Colors.white` hits in the four migrated files — `dyk_theme.dart` has `surfaceTintColor: Colors.transparent` (not a match) but `cardTheme` uses `Colors.white`, and `passim_nav_bar.dart` may still have one.

The failure is the point: it tells you exactly what is left.

- [ ] **Step 3: Fix the offenders**

Replace each reported `Colors.white` with `PassimColors.onPhoto` where it is a deliberate white over photo/scrim/amber, or delete the colour so the theme supplies it. In `dyk_theme.dart` the `cardTheme` white is a light-mode *surface*, not an on-photo colour — introduce a named constant for it instead:

```dart
  /// Card and sheet surface in light mode. Pure white against sand gives the
  /// separation that a tinted card would lose.
  static const card = Color(0xFFFFFFFF);
```

and use `PassimColors.card` in `_base()` and in the Task 3 test's expectation.

- [ ] **Step 4: Run the full suite**

Run: `flutter test`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add test/theme/theme_contract_test.dart lib/theme/dyk_theme.dart
git commit -m "test(theme): guard the no-literal-white rule

A contrast test over every screen would be thorough and brittle. This
watches the exact rule the migration introduced instead, over an explicit
list of reviewed files that grows as screens are migrated — which is what
turns an unmeasurable 195-site job into one with a finish line.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Verification before calling this done

- [ ] `flutter test` — all tests pass, count reported.
- [ ] `flutter analyze` — no issues.
- [ ] On a device, in **light** mode: splash shows one pin; every tab's chrome is light; the nav bar is light and its labels readable; all five maps are light; Settings shows the picker and the choice survives a restart.
- [ ] On a device, in **dark** mode: nothing changed from before this work.
- [ ] The wordmark's optical centring is checked by eye at the top of the app in light mode. `logo_centering_test.dart` measures the widget's centre, not the pixels, so it cannot catch a logo whose content sits off-centre inside its own canvas — and the blue logo lacks the 49 px right padding the dark one has.

## Known to be out of scope

The 195 hardcoded whites across the 38 screen files. After this plan, the immersive content screens (hotspot detail, tour detail, active tour, stop detail) are still hardcoded dark in both modes. That is stage 4–5 of the spec and needs its own plan and a design pass with Jose, because making a full-bleed photo screen light is a design decision per screen, not a colour swap.
