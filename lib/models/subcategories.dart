/// What kind of place a story is attached to.
///
/// Not "what business is this" — Passim is not a restaurant guide, and a
/// tourist who only wants dinner opens a map app. These are the kinds of
/// place a Passim story happens at, so someone browsing can say "I'd like to
/// hear something somewhere I can also sit down and eat".
///
/// Only Leisure has them today. The filter row appears for whichever
/// categories are listed here and stays hidden for the rest, so adding
/// subcategories to History later needs nothing but a new entry.
///
/// Keys are what lives in the database; labels are translated (i18n key
/// `sub_<key>`). The same keys are offered in the admin's subcategory menu —
/// dyk-admin/src/subcategories.ts. Changing one list means changing both, and
/// the test beside this file exists to make that impossible to forget.
const Map<String, List<String>> subcategoriesByCategory = {
  'otium': ['restaurants', 'bars', 'museums', 'natural_spaces', 'shops'],
};

/// The chip for everything not yet classified.
///
/// Deliberately a real option rather than a silent omission. Roughly a
/// quarter of Leisure hotspots have no subcategory, and a filter that hid
/// them would make the map lie while the tagging catches up. It is a safety
/// net, not a destination: a restaurant nobody has tagged still will not
/// appear under Restaurants.
const String unclassifiedKey = 'other';

/// Subcategory chips to offer for the selected categories, in a stable order.
///
/// Returns an empty list when nothing selected has subcategories, which is
/// what keeps the row hidden rather than empty.
List<String> subcategoryChipsFor(Set<String> selectedCategories) {
  final chips = <String>[];
  for (final entry in subcategoriesByCategory.entries) {
    if (!selectedCategories.contains(entry.key)) continue;
    for (final sub in entry.value) {
      if (!chips.contains(sub)) chips.add(sub);
    }
  }
  if (chips.isNotEmpty) chips.add(unclassifiedKey);
  return chips;
}

/// Does this hotspot survive the chosen subcategory chips?
///
/// Choosing nothing means everything, so the filter starts out invisible in
/// its effect as well as in its appearance. A hotspot in a category with no
/// subcategories at all is never filtered out by this: picking Restaurants
/// narrows Leisure and leaves History alone, which is what the row implies
/// by only appearing under the categories it governs.
bool matchesSubcategories(
  String category,
  String? subcategory,
  Set<String> chosen,
) {
  if (chosen.isEmpty) return true;
  final subs = subcategoriesByCategory[category];
  if (subs == null) return true; // this category is not being narrowed
  final key = (subcategory == null || !subs.contains(subcategory))
      ? unclassifiedKey
      : subcategory;
  return chosen.contains(key);
}
