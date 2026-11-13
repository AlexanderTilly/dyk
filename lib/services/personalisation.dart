import 'package:flutter/foundation.dart';

import '../models/hot_deal.dart';
import '../models/profile_questions.dart';
import '../models/tour.dart';

/// What the interest answers DO. Pure functions, no widgets, no storage.
///
/// The rule that governs this whole file: **answers reorder, they never
/// filter.** Every function returns exactly the items it was given, in an
/// order that may differ. Someone who picks food still sees every ghost
/// story, just further down, so a wrong guess costs a scroll and Passim never
/// withholds anything.
///
/// Three things hold everywhere:
///  * No answers, or stale answers (from a question set we no longer ask),
///    return the input order untouched ([Personalisation.active]).
///  * Offers only rank by answers with the separate consent
///    ([orderDeals]); using answers to pick offers is profiling.
///  * Nothing is inferred beyond the answer itself. Answering D to "who with"
///    lifts family-friendly places. It does not mean the person has children
///    and nothing is recorded or derived from it.

/// The answers plus the offers consent, as one value the UI can hold.
@immutable
class Personalisation {
  final ProfileAnswers answers;
  final bool offersConsent;

  const Personalisation(this.answers, {this.offersConsent = false});

  static const none = Personalisation(ProfileAnswers.empty);

  /// False means "behave exactly as before".
  bool get active => !answers.isEmpty && !answers.isStale;
}

// ---------------------------------------------------------------------------
// THE MAPPING. The only place option letters are tied to app keys.
// Letters are from lib/models/profile_questions.dart; keys from themes.dart
// and subcategories.dart. A key left out of a map simply gets no lift.
// ---------------------------------------------------------------------------

/// q2, which stories → tour themes (themes.dart `tourThemes`).
const Map<String, List<String>> _q2Themes = {
  'A': ['churches', 'walls_gates', 'palaces'], // history / monuments
  'B': ['ghosts'], // mysteries / legends
  'C': ['food_drink', 'old_shops'], // food / traditions
  'D': ['modernisme', 'museums'], // art / culture
};

/// q2 → tour `type` (tours have no theme tags, only a type).
const Map<String, List<String>> _q2TourTypes = {
  'A': ['history_walk'],
  'C': ['food_drink'],
};

/// q6, local recommendations → Leisure subcategory chips (subcategories.dart).
const Map<String, List<String>> _q6Subcategories = {
  'A': ['restaurants', 'bars'],
  'B': ['shops'],
  'C': ['museums'],
  'D': ['natural_spaces'],
};

/// q4 D (family and children) → family-friendly places. The data has no
/// family flag, so parks and open spaces are the stand-in. A weaker lift than
/// q6, which is a direct statement about what the person wants.
const Map<String, List<String>> _q4Subcategories = {
  'D': ['natural_spaces'],
};

/// q3, how they explore → tour length. C wants short; D and A take longer.
const int shortTourMinutes = 60;
const int longTourMinutes = 120;

// ---------------------------------------------------------------------------

/// Stable reorder: highest score first, ties keep their input order.
List<T> _rise<T>(List<T> items, int Function(T) score) {
  final scored = [
    for (var i = 0; i < items.length; i++) (i, score(items[i]), items[i]),
  ];
  scored.sort((a, b) {
    final c = b.$2.compareTo(a.$2);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return [for (final s in scored) s.$3];
}

int _hits(ProfileAnswers a, String q, Map<String, List<String>> map, String key,
    [int weight = 1]) {
  var n = 0;
  for (final letter in a.of(q)) {
    if (map[letter]?.contains(key) ?? false) n += weight;
  }
  return n;
}

/// Theme reel order (q2).
List<String> orderThemes(List<String> themes, Personalisation p) {
  if (!p.active) return themes;
  return _rise(themes, (t) => _hits(p.answers, 'q2', _q2Themes, t));
}

/// Leisure chip order (q6, and q4 D more gently). [unclassifiedKey] style
/// catch-all chips have no hits, so they stay behind whatever was lifted but
/// keep their place relative to the unlifted ones.
List<String> orderSubcategories(List<String> chips, Personalisation p) {
  if (!p.active) return chips;
  return _rise(
      chips,
      (c) =>
          _hits(p.answers, 'q6', _q6Subcategories, c, 2) +
          _hits(p.answers, 'q4', _q4Subcategories, c));
}

/// Order of the tour sections by type (q2).
List<String> orderTourTypes(List<String> types, Personalisation p) {
  if (!p.active) return types;
  return _rise(types, (t) => _hits(p.answers, 'q2', _q2TourTypes, t));
}

/// Order of tours within a section (q3). Tours with no known length stay
/// neutral.
List<Tour> orderToursByLength(List<Tour> tours, Personalisation p) {
  if (!p.active) return tours;
  final a = p.answers.of('q3');
  final wantShort = a.contains('C');
  final wantLong = a.contains('D') || a.contains('A');
  if (wantShort == wantLong) return tours; // none, or contradictory
  return _rise(tours, (t) {
    final m = t.estMinutes;
    if (m == null) return 0;
    if (wantShort) return m <= shortTourMinutes ? 1 : 0;
    return m >= longTourMinutes ? 1 : 0;
  });
}

/// Hot Deals order (q5). **Only with consent**: without it the input order is
/// returned as-is, exactly as today.
///
/// The deal data carries few signals, so only D (easy, convenient) has
/// something real to act on: it lifts deals shown at the till with no scan.
///
/// B (unique, exclusive) was mapped to time-limited deals and then removed.
/// A deal that ends on Friday is not an exclusive one — that was inventing a
/// signal the data does not carry, and this is the one place where a wrong
/// guess changes which OFFERS a person sees, which is the part consent was
/// asked for. A and C have no signal either and change nothing. Better to
/// move nothing than to move the wrong thing here.
List<HotDeal> orderDeals(List<HotDeal> deals, Personalisation p) {
  if (!p.offersConsent || !p.active) return deals;
  final a = p.answers.of('q5');
  if (a.isEmpty) return deals;
  return _rise(deals, (d) {
    var s = 0;
    if (a.contains('D') && d.redeemMode == 'show') s++;
    return s;
  });
}
