import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:palma_app/models/subcategories.dart';

void main() {
  group('the list itself', () {
    // Pinned on purpose. The admin offers the same keys from
    // dyk-admin/src/subcategories.ts, and nothing at runtime compares the two
    // repos. Changing the taxonomy here fails this test, which is the moment
    // to go and change the admin as well.
    test('is exactly what the admin offers', () {
      expect(subcategoriesByCategory, {
        'otium': ['restaurants', 'bars', 'museums', 'natural_spaces', 'shops'],
      });
      expect(unclassifiedKey, 'other');
    });

    test('keys are database-shaped: lower case, no spaces', () {
      for (final subs in subcategoriesByCategory.values) {
        for (final s in subs) {
          expect(s, matches(RegExp(r'^[a-z][a-z_]*$')), reason: s);
        }
      }
    });
  });


  group('the database agrees', () {
    // The third copy of this taxonomy lives in a CHECK constraint, and it is
    // the only one that can REJECT a write. On 2026-10-21 the admin offered
    // "Shop" while the constraint still listed the pre-2026-10-16 keys, so
    // every save failed with hotspots_subcategory_check. The two code lists
    // had tests pinning each other; the database had nobody watching it.
    test('migration 054 permits exactly the keys the app offers', () {
      final sql =
          File('supabase/migrations/054_subcategory_constraint.sql')
              .readAsStringSync();
      // Only the constraint body. Bounded at both ends on purpose: the file's
      // closing notes quote 'leisure' and 'art' as values to check are gone,
      // and an unbounded read swallows them and reports a drift that is only
      // prose.
      final body = sql
          .split('add constraint hotspots_subcategory_check')
          .last
          .split('commit;')
          .first;
      final permitted = RegExp(r"'([a-z_]+)'")
          .allMatches(body)
          .map((m) => m.group(1)!)
          .toSet();

      final offered = {
        for (final subs in subcategoriesByCategory.values) ...subs,
        // History's keys are not in subcategoriesByCategory — only Leisure
        // has chips in the app — but the admin still writes them, so the
        // constraint must allow them.
        'building', 'work_of_art', 'historical_figure',
      };

      expect(permitted, offered,
          reason: 'the CHECK constraint and the app have drifted apart; '
              'change both, and dyk-admin/src/subcategories.ts too');
    });
  });

  group('subcategoryChipsFor', () {
    test('offers nothing when the selection has no subcategories', () {
      expect(subcategoryChipsFor({'history', 'headline'}), isEmpty);
    });

    test('offers the category list plus Other', () {
      expect(subcategoryChipsFor({'otium'}),
          ['restaurants', 'bars', 'museums', 'natural_spaces', 'shops', 'other']);
    });

    test('other categories alongside do not change the chips', () {
      expect(subcategoryChipsFor({'history', 'otium', 'hotdeal'}),
          subcategoryChipsFor({'otium'}));
    });

    test('an empty selection offers nothing', () {
      expect(subcategoryChipsFor({}), isEmpty);
    });
  });

  group('matchesSubcategories', () {
    test('choosing nothing keeps everything', () {
      expect(matchesSubcategories('otium', 'bars', {}), isTrue);
      expect(matchesSubcategories('otium', null, {}), isTrue);
    });

    test('narrows within the category', () {
      expect(matchesSubcategories('otium', 'restaurants', {'restaurants'}), isTrue);
      expect(matchesSubcategories('otium', 'bars', {'restaurants'}), isFalse);
    });

    test('leaves categories without subcategories alone', () {
      // Picking Restaurants must not empty the map of history: that row only
      // appears under the categories it governs, and it governs only those.
      expect(matchesSubcategories('history', null, {'restaurants'}), isTrue);
      expect(matchesSubcategories('history', 'building', {'restaurants'}), isTrue);
    });

    test('untagged hotspots answer to Other', () {
      expect(matchesSubcategories('otium', null, {'other'}), isTrue);
      expect(matchesSubcategories('otium', null, {'restaurants'}), isFalse);
    });

    test('a retired value counts as Other rather than vanishing', () {
      // 'leisure' and 'art' existed before this taxonomy. The migration clears
      // them, but a row that escapes it must still be reachable, not invisible.
      expect(matchesSubcategories('otium', 'leisure', {'other'}), isTrue);
      expect(matchesSubcategories('otium', 'leisure', {'restaurants'}), isFalse);
    });

    test('several chips are an or, not an and', () {
      expect(matchesSubcategories('otium', 'bars', {'restaurants', 'bars'}), isTrue);
    });
  });
}
