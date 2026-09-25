import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// The 3D Passim pin that marks where you are.
///
/// A real glTF model rather than a flat image, so it stands on the street and
/// tilts with the camera the way the buildings do — on a pitched map a flat
/// puck reads as a sticker lying on the ground.
///
/// It also fixes something the 2D puck could not: the SDK rotates a flat puck
/// image with the compass, which would have rolled a drop-shaped pin onto its
/// side every time you turned. A model rotates about its own vertical axis
/// instead, so the pin stays upright and only faces a different way.
///
/// The model is prepared by tool/prepare_puck_model.py — the raw export has
/// no normals and no material, and renders flat grey without them.
const String passimPuckModel = 'asset://assets/models/passim_puck.glb';

/// Metres, roughly. The model is about 1.9 units tall, so this lands it at a
/// couple of metres on the ground — big enough to find at a glance, small
/// enough not to cover the street you are standing in.
const double _puckScale = 12.0;

LocationComponentSettings passimPuckSettings() => LocationComponentSettings(
      enabled: true,
      // The old flat puck had its glow painted into the image; a model has no
      // such halo, and the SDK's pulse would ring a 3D object oddly, so it
      // stays off and the pin carries itself.
      pulsingEnabled: false,
      puckBearingEnabled: true,
      locationPuck: LocationPuck(
        locationPuck3D: LocationPuck3D(
          modelUri: passimPuckModel,
          modelScale: [_puckScale, _puckScale, _puckScale],
          // No rotation. The first attempt tipped it 90 degrees about X on the
          // assumption that glTF's Y-up needed converting to Mapbox's Z-up —
          // but Mapbox already does that, so the extra turn laid the pin flat
          // on the street. Leave it alone and it stands.
          modelRotation: [0.0, 0.0, 0.0],
          modelCastShadows: true,
          modelReceiveShadows: false,
          // Keeps a constant size on screen as you zoom, like the flat puck
          // did. Without it the pin balloons at street level.
          modelScaleMode: ModelScaleMode.VIEWPORT,
        ),
      ),
    );
