import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:palma_app/i18n/i18n.dart';
import 'package:palma_app/models/hotspot.dart';
import 'package:palma_app/screens/hotspot_detail_screen.dart';
import 'package:palma_app/services/audio_service.dart';
import 'package:palma_app/theme/dyk_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// flutter_test draws every glyph as a full-em box, which is far wider than
/// real text — a width test against that measures a phone nobody owns. Load
/// the Roboto the SDK ships, the Android default.
Future<void> _loadRoboto() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? 'C:/flutter/flutter';
  final loader = FontLoader('Roboto');
  for (final f in ['regular', 'black']) {
    final bytes = File('$root/bin/cache/artifacts/material_fonts/roboto-$f.ttf')
        .readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

/// No images: an Image.network in a widget test fails its request, and that
/// exception would land in takeException() and be mistaken for the overflow
/// this test is looking for.
final _hotspot = const Hotspot(
  id: 'h1',
  name: 'Can Morell',
  subtitle: 'A courtyard off Carrer de Sant Feliu',
  description: 'Short enough not to matter here.',
  lat: 39.5696,
  lng: 2.6502,
  radiusMeters: 40,
  audioFile: 'https://example.invalid/story.mp3',
  images: [],
  year: '1640',
);

void main() {
  setUpAll(() {
    // Otherwise google_fonts tries to fetch over the network and throws.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  /// Jose, on a narrow phone: the right edge of the player card was cut off,
  /// so the 1x speed button and the total time sat half outside the screen.
  /// The title row let its Text grow unbounded, and the German label is 25
  /// characters — it pushed the chip clean off.
  ///
  /// 320 dp is the narrowest phone still in use; 360 is the common Android
  /// width. Both are checked, in every language, because the label that
  /// breaks the layout is the longest translation and not the English one.
  for (final width in [320.0, 360.0]) {
    for (final lang in ['en', 'es', 'ca', 'de']) {
      testWidgets('player card fits at $width dp in $lang', (t) async {
        SharedPreferences.setMockInitialValues({});
        await I18n.instance.load(await SharedPreferences.getInstance());
        await I18n.instance.setCode(lang);
        addTearDown(() => I18n.instance.setCode('en'));
        await _loadRoboto();

        t.view.physicalSize = Size(width * 3, 800 * 3);
        t.view.devicePixelRatio = 3.0;
        addTearDown(t.view.reset);

        await t.pumpWidget(MaterialApp(
          theme: dykLightTheme(),
          home: HotspotDetailScreen(
            hotspot: _hotspot,
            audioService: AudioService(),
          ),
        ));
        await t.pump();

        // A RenderFlex overflow is reported as an exception during layout,
        // so an empty one here is the whole assertion.
        expect(t.takeException(), isNull,
            reason: 'the player card overflows at $width dp in $lang');
      });
    }
  }
}
