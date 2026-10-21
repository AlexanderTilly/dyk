import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'dyk_puck.dart';

/// Where you are on the map: a flat puck with a heading wedge.
///
/// This was a 3D glTF pin for a while (the model is still in the repo at
/// assets/models/passim_puck.glb, built by tool/prepare_puck_model.py). It was
/// tried on a phone on 2026-10-21 and put back, because a pin standing on the
/// street competes with the place pins around it: on a pitched map you get a
/// field of drop shapes and your own position stops being the thing your eye
/// finds first. A puck reads as "you", a pin reads as "a place".
///
/// The wedge is what makes it useful. `puckBearingEnabled` has the SDK rotate
/// the image to the compass, which is fine here precisely because the puck is
/// round — that rotation is what rolled the drop-shaped pin onto its side and
/// prompted the 3D attempt in the first place.
///
/// The bytes are built once. The drawing is cheap, but every map screen asks
/// for these settings and there is no reason to re-render the same PNG.
LocationComponentSettings? _cached;

Future<LocationComponentSettings> passimPuckSettings() async {
  return _cached ??= LocationComponentSettings(
    enabled: true,
    pulsingEnabled: false, // the halo is painted into the image
    puckBearingEnabled: true, // the wedge shows which way you are walking
    locationPuck: LocationPuck(
      locationPuck2D: DefaultLocationPuck2D(topImage: await buildDykPuck()),
    ),
  );
}
