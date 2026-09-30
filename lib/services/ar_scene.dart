/// A place you can hold the phone up in and see as it once was.
///
/// Not AR in the ARKit sense: no tracking, no depth, no anchors. It is the
/// camera, the compass, and a photograph of the same view taken from the same
/// spot — which is all an overlay needs when the viewer stands still and only
/// turns. The heavy machinery starts to matter when people walk around, and
/// that is a different product.
class ArView {
  /// Compass bearing this photograph faces, in degrees clockwise from north.
  final double bearing;

  /// The view as it is now. Not shown in the app — the live camera plays that
  /// part — but kept so the pair can be checked for drift, and so the demo
  /// survives a camera that refuses to open.
  final String now;

  /// The same view, as it was.
  final String then;

  const ArView({required this.bearing, required this.now, required this.then});
}

class ArScene {
  final String title;
  final String era;

  /// Where the photographs were taken from. Not used to gate the screen yet —
  /// a demo that refuses to open because the GPS is indoors and confused is a
  /// demo that fails in the room it was built for. It is here so the scene can
  /// become a hotspot without moving the address somewhere else first.
  final double lat;
  final double lng;

  final List<ArView> views;

  const ArScene({
    required this.title,
    required this.era,
    required this.lat,
    required this.lng,
    required this.views,
  });
}

/// Shortest turn from [a] to [b], in degrees, always 0..180.
///
/// Bearings wrap, so plain subtraction lies: 350 and 10 are twenty degrees
/// apart, not three hundred and forty. Every heading comparison here goes
/// through this.
double angleBetween(double a, double b) {
  final d = (a - b).abs() % 360;
  return d > 180 ? 360 - d : d;
}

/// The view the phone is pointing closest to.
///
/// Nearest-bearing rather than fixed sectors, so a scene works with three
/// photographs or with eight without the rule changing. Returns null for an
/// empty scene — a scene with no views has nothing to show, and that is not
/// an error worth throwing over in front of an audience.
ArView? viewForHeading(ArScene scene, double heading) {
  if (scene.views.isEmpty) return null;
  var best = scene.views.first;
  var bestDelta = angleBetween(heading, best.bearing);
  for (final v in scene.views.skip(1)) {
    final d = angleBetween(heading, v.bearing);
    if (d < bestDelta) {
      best = v;
      bestDelta = d;
    }
  }
  return best;
}

/// The office, for the investor demo.
///
/// Read off the phone's compass standing on the spot: 39°34'25"N 2°39'21"E,
/// Palma. One bearing is measured (279°); the other two are still placeholders
/// from the test shoot, so the screen also lets you swipe between views by
/// hand and shows a live heading to read the missing numbers off with.
const officeScene = ArScene(
  title: 'The office',
  era: '1926',
  lat: 39.5736,
  lng: 2.6558,
  views: [
    ArView(
      bearing: 0,
      now: 'assets/ar/office/wall_now.jpg',
      then: 'assets/ar/office/wall_then.jpg',
    ),
    ArView(
      bearing: 120,
      now: 'assets/ar/office/glass_now.jpg',
      then: 'assets/ar/office/glass_then.jpg',
    ),
    ArView(
      bearing: 240,
      now: 'assets/ar/office/bay_now.jpg',
      then: 'assets/ar/office/bay_then.jpg',
    ),
  ],
);
