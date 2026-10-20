import '../i18n/i18n.dart';

/// What a tour is about: the reason a walk through the old town exists.
///
/// The tour generator picks hotspots by theme, so these keys are what each
/// hotspot is tagged with in `hotspots.themes`. Order is the order the
/// admin offers them in, and it is pinned by the test beside this file.
///
/// The same keys live in dyk-admin/src/themes.ts. Nothing at runtime compares
/// the two repos, so changing one list means changing both, and the tests
/// exist to make forgetting the other one fail loudly.
///
/// `ghosts` is the existing `headline` category. Those hotspots get the tag
/// by backfill (migration 050), not by asking a model.
const List<String> tourThemes = [
  'food_drink',
  'churches',
  'ghosts',
  'walls_gates',
  'palaces',
  'old_shops',
  'the_sea',
  'modernisme',
];

/// The translated name of a theme, for showing in a list or chip.
///
/// Labels are looked up under `theme_<key>`, the same way subcategory labels
/// are under `sub_<key>`. A key with no string yet shows as the key itself,
/// which is what `tr` does for anything missing, so the strings can land in a
/// later change without this function needing to know.
String themeLabel(String key) => tr('theme_$key');
