import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palma_app/theme/dyk_theme.dart';

/// Files that have been through the light-mode migration. A literal white in
/// one of these is a regression: the rule is that every white is either
/// deleted, so the colour is inherited, or named PassimColors.onPhoto so it
/// states why it is deliberate.
///
/// This list grows as screens are migrated. It is what makes an otherwise
/// unmeasurable 195-site job finishable — a file on this list is reviewed.
const migratedFiles = [
  'lib/theme/dyk_theme.dart',
  'lib/screens/active_tour_screen.dart',
  'lib/screens/app_shell.dart',
  'lib/screens/auth_screen.dart',
  'lib/screens/deal_detail_screen.dart',
  'lib/screens/hotspot_detail_screen.dart',
  'lib/screens/list_screen.dart',
  'lib/screens/map_screen.dart',
  'lib/screens/navigate_screen.dart',
  'lib/screens/notification_center_screen.dart',
  'lib/screens/onboarding/background_location_screen.dart',
  'lib/screens/onboarding/consent_screen.dart',
  'lib/screens/onboarding/interests_screen.dart',
  'lib/screens/onboarding/location_screen.dart',
  'lib/screens/onboarding/notifications_screen.dart',
  'lib/screens/onboarding/ready_screen.dart',
  'lib/screens/onboarding/welcome_screen.dart',
  'lib/screens/paused_screen.dart',
  'lib/screens/pickpocket_map_screen.dart',
  'lib/screens/premium_screen.dart',
  'lib/screens/settings_screen.dart',
  'lib/screens/splash_screen.dart',
  'lib/screens/stop_detail_screen.dart',
  'lib/screens/support_screen.dart',
  'lib/screens/tabs/city_packs_tab.dart',
  'lib/screens/tabs/explore_tab.dart',
  'lib/screens/tabs/more_tab.dart',
  'lib/screens/tabs/nearby_tab.dart',
  'lib/screens/tabs/profile_tab.dart',
  'lib/screens/tabs/saved_tab.dart',
  'lib/screens/tabs/tours_tab.dart',
  'lib/screens/tour_complete_screen.dart',
  'lib/screens/tour_detail_screen.dart',
  'lib/screens/welcome_city_screen.dart',
  'lib/widgets/audio_player_widget.dart',
  'lib/widgets/category_badge.dart',
  'lib/widgets/dyk_page_route.dart',
  'lib/widgets/dyk_puck.dart',
  'lib/widgets/flag_icon.dart',
  'lib/widgets/hotspot_list_tile.dart',
  'lib/widgets/internal_ad_banner.dart',
  'lib/widgets/mini_player.dart',
  'lib/widgets/passim_background.dart',
  'lib/widgets/passim_nav_bar.dart',
  'lib/widgets/photo_pin.dart',
  'lib/widgets/pickpocket_banner.dart',
  'lib/widgets/unlock_buttons.dart',
];

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
    expect(dykLightTheme().cardTheme.color, PassimColors.card);
    expect(dykDarkTheme().cardTheme.color, PassimColors.surface);
  });

  test('icons follow the mode', () {
    expect(dykLightTheme().iconTheme.color, PassimColors.ink);
    expect(dykDarkTheme().iconTheme.color, PassimColors.onPhoto);
  });

  test('onPhoto is white — it is white text, just named for its reason', () {
    expect(PassimColors.onPhoto, Colors.white);
  });

  test('migrated files use onPhoto, never a literal white', () {
    final offenders = <String>[];
    for (final path in migratedFiles) {
      final lines = File(path).readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // The palette itself has to name the literal once, for each
        // deliberate white it defines.
        if (path.endsWith('dyk_theme.dart') &&
            (line.contains('onPhoto =') || line.contains('card ='))) {
          continue;
        }
        // `PassimColors.whiteArgb` is a raw integer for a Mapbox style layer,
        // not a colour in the widget tree. Mapbox layers take ints and inherit
        // nothing from the theme, so those sites are switched by hand and are
        // not what this rule is about.
        if (line.contains('Colors.white') && !line.contains('whiteArgb')) {
          offenders.add('$path:${i + 1}: ${line.trim()}');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'use PassimColors.onPhoto, or delete the colour so the '
            'theme supplies it:\n${offenders.join('\n')}');
  });
}
