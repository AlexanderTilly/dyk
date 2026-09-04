import 'package:flutter/material.dart';

/// Passim brand palette — the single source of truth for colour.
///
/// Nothing outside this class should hardcode a brand colour: a hex literal
/// in a screen is how a rebrand turns into a week of hunting. Semantic names
/// (ink, surface, sand) rather than "navy" or "black" so the next palette
/// change stays a one-file edit.
class PassimColors {
  /// Amber accent — buttons, pins, highlights.
  static const brand = Color(0xFFFFC21A);

  /// Deep navy: app background in dark mode, and text on light surfaces.
  static const ink = Color(0xFF071A2F);

  /// Raised navy: cards and sheets sitting on [ink].
  static const surface = Color(0xFF223247);

  /// Warm off-white: light-mode background.
  static const sand = Color(0xFFF4F1E8);

  /// Success / "unlocked" green. Not a brand colour, kept for status only.
  static const green = Color(0xFF22C55E);

  // Mapbox style layers take raw ARGB ints rather than [Color], so the same
  // palette is mirrored here. Keep the pairs in sync.
  static const brandArgb = 0xFFFFC21A;
  static const inkArgb = 0xFF071A2F;
  static const whiteArgb = 0xFFFFFFFF;
}

/// Previous brand names, kept so the 200-plus existing references keep
/// working while screens migrate to [PassimColors]. Same values.
class DykColors {
  static const yellow = PassimColors.brand;
  static const black = PassimColors.ink;
  static const cream = PassimColors.sand;
  static const green = PassimColors.green;
}

ThemeData dykLightTheme() => _base(Brightness.light);
ThemeData dykDarkTheme() => _base(Brightness.dark);

ThemeData _base(Brightness b) {
  final dark = b == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    scaffoldBackgroundColor: dark ? PassimColors.ink : PassimColors.sand,
    colorScheme: ColorScheme.fromSeed(
      seedColor: PassimColors.brand,
      brightness: b,
      primary: PassimColors.brand,
      surface: dark ? PassimColors.surface : PassimColors.sand,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: PassimColors.brand,
        foregroundColor: PassimColors.ink,
        textStyle: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      ),
    ),
  );
}

/// Transport-mode icon (replaces the old emoji glyphs).
IconData transportIcon(String mode) => switch (mode) {
      'cycling' => Icons.directions_bike,
      'driving' => Icons.directions_car,
      'boat' => Icons.sailing,
      _ => Icons.directions_walk,
    };

/// Best-effort icon for a free-text checklist item ("Sunscreen", "Swimwear").
IconData checklistIcon(String item) {
  final l = item.toLowerCase();
  if (l.contains('sun') || l.contains('sol')) return Icons.wb_sunny_outlined;
  if (l.contains('shoe') || l.contains('skor') || l.contains('zapat')) {
    return Icons.directions_walk;
  }
  if (l.contains('swim') || l.contains('bad') || l.contains('bikini')) {
    return Icons.pool_outlined;
  }
  if (l.contains('water') || l.contains('vatten') || l.contains('agua') ||
      l.contains('bottle')) {
    return Icons.water_drop_outlined;
  }
  if (l.contains('camera') || l.contains('kamera')) {
    return Icons.photo_camera_outlined;
  }
  if (l.contains('towel') || l.contains('handduk')) {
    return Icons.waves_outlined;
  }
  if (l.contains('snorkel') || l.contains('cyklop')) {
    return Icons.scuba_diving;
  }
  if (l.contains('power') || l.contains('charg') || l.contains('bank')) {
    return Icons.battery_charging_full;
  }
  if (l.contains('snack') || l.contains('food') || l.contains('salad') ||
      l.contains('recept') || l.contains('lunch')) {
    return Icons.lunch_dining_outlined;
  }
  if (l.contains('hat') || l.contains('hatt') || l.contains('cap')) {
    return Icons.face_2_outlined;
  }
  return Icons.check_circle_outline;
}

/// Two-footprint "steps" icon (Material has no footprints glyph).
class FootstepsIcon extends StatelessWidget {
  final double size;
  final Color color;
  const FootstepsIcon({super.key, this.size = 22, this.color = DykColors.yellow});

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(size, size),
        painter: _FeetPainter(color),
      );
}

class _FeetPainter extends CustomPainter {
  final Color color;
  _FeetPainter(this.color);

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color;
    void foot(double cx, double cy, double angle) {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(angle);
      // Sole + heel + toe pad.
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset.zero, width: s.width * 0.26, height: s.height * 0.42),
          p);
      canvas.drawCircle(Offset(0, s.height * 0.30), s.width * 0.10, p);
      canvas.restore(); // undo the per-foot rotation — must not leak
    }

    foot(s.width * 0.32, s.height * 0.30, -0.15); // left foot, slightly ahead
    foot(s.width * 0.68, s.height * 0.58, 0.15); // right foot behind
  }

  @override
  bool shouldRepaint(_FeetPainter old) => old.color != color;
}
