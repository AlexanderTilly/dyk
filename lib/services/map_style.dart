import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';


/// One map look, applied everywhere.
///
/// Every map in the app uses Mapbox Standard rather than the streets/dark
/// pair. Standard carries its own light presets and colour configuration, so
/// light and dark are the same style asking for a different time of day —
/// which means there is one set of layer colours to tune instead of two, and
/// 3D buildings and landmarks survive in both. Palma's cathedral renders as
/// an actual model, which is the point in a tourist app.
///
/// The colours are Mapbox's own. What this file changes is the time of day,
/// the 3D, and the labels — the things that belong to us. See the note in
/// [applyPassimMapStyle] for why hand-tinting the ground was a mistake.
const String passimMapStyle = MapboxStyles.STANDARD;

/// Mapbox addresses the basemap inside a style by its import id.
const String _basemap = 'basemap';

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

    // Mapbox's own palette, deliberately.
    //
    // The first attempt set theme 'monochrome' and tinted colorLand to sand.
    // Buildings take their tone from the ground, so near-white land under a
    // desaturating theme produced near-white buildings on near-white ground —
    // the 3D was still there and you could not see it. Standard's default
    // palette already separates ground, built-up area and water properly, and
    // is better tuned than anything worth hand-rolling here.
    //
    // 'faded' is the middle setting if this ever reads as too colourful.
    await set('theme', 'default');

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
