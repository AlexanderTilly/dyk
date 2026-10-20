import 'package:flutter_test/flutter_test.dart';
import 'package:palma_app/models/themes.dart';

void main() {
  group('the list itself', () {
    // Pinned on purpose. The admin offers the same keys from
    // dyk-admin/src/themes.ts, and nothing at runtime compares the two repos.
    // Changing the list here fails this test, which is the moment to change
    // the admin as well.
    test('is exactly the eight keys, in order', () {
      expect(tourThemes, [
        'food_drink',
        'churches',
        'ghosts',
        'walls_gates',
        'palaces',
        'old_shops',
        'the_sea',
        'modernisme',
      ]);
    });

    test('keys are database-shaped: lower case, no spaces', () {
      for (final key in tourThemes) {
        expect(key, matches(RegExp(r'^[a-z][a-z_]*$')), reason: key);
      }
    });

    test('includes ghosts, the key backfilled from the headline category', () {
      expect(tourThemes, contains('ghosts'));
    });
  });

  group('themeLabel', () {
    test('keys the label off the theme key', () {
      expect(themeLabel('ghosts'), 'theme_ghosts');
      expect(themeLabel('food_drink'), 'theme_food_drink');
    });
  });
}
