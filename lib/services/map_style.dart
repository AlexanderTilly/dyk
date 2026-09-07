// mapbox_maps_flutter exports its own `Color`, so ui.Color is spelled out
// rather than imported bare — the same collision that made `Position` need an
// alias elsewhere in this app.
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../theme/dyk_theme.dart';

/// One map look, applied everywhere.
///
/// Every map in the app uses Mapbox Standard rather than the streets/dark
/// pair. Standard carries its own light presets and colour configuration, so
/// light and dark are the same style asking for a different time of day —
/// which means there is one set of layer colours to tune instead of two, and
/// 3D buildings and landmarks survive in both. Palma's cathedral renders as
/// an actual model, which is the point in a tourist app.
///
/// The palette is deliberately muted. A guide's map should be quiet so the
/// amber pins are the only saturated thing on screen and the eye goes
/// straight to them; a colourful basemap competes with the content it exists
/// to carry.
const String passimMapStyle = MapboxStyles.STANDARD;

/// Mapbox addresses the basemap inside a style by its import id.
const String _basemap = 'basemap';

/// Hex string in the form Mapbox config properties expect.
String _hex(ui.Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Apply the Passim look to [map] for the given brightness.
///
/// Safe to call again on the same map: switching theme only changes config
/// properties, so the basemap re-lights in place without reloading the style
/// or dropping the layers and images the screen has already added.
Future<void> applyPassimMapStyle(MapboxMap map, {required bool dark}) async {
  Future<void> set(String key, Object value) =>
      map.style.setStyleImportConfigProperty(_basemap, key, value);

  try {
    // Time of day does most of the work: it re-lights the whole basemap,
    // including how the 3D extrusions are shaded.
    await set('lightPreset', dark ? 'night' : 'day');

    // Monochrome drains the basemap of competing hue. This is the single
    // biggest reason the map reads as considered rather than generic.
    await set('theme', 'monochrome');

    // Ground and water tinted towards the app's own surfaces, so the map
    // belongs to the screen it sits in rather than looking pasted on.
    await set('colorLand', _hex(dark ? PassimColors.ink : PassimColors.sand));
    await set('colorWater',
        _hex(dark ? const ui.Color(0xFF0B2136) : const ui.Color(0xFFDDE6EC)));
    await set('colorGreenspace',
        _hex(dark ? const ui.Color(0xFF12283B) : const ui.Color(0xFFE4E8DA)));

    // Keep the 3D: it is why the tilted camera on Nearby is worth having.
    await set('show3dObjects', true);

    // Points of interest are Mapbox's own labels — restaurants, shops,
    // brands. They clutter the map and compete with our hotspots, which are
    // the only places we want tapped. Streets and place names stay.
    await set('showPointOfInterestLabels', false);
  } catch (e) {
    // A style config key that a future Standard version drops must not take
    // the map down with it — an unstyled map still navigates.
    debugPrint('Passim map style: could not apply config ($e)');
  }
}
