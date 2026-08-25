import 'package:flutter/material.dart';

class DykColors {
  static const yellow = Color(0xFFFFC107);
  static const black = Color(0xFF1A1A1A);
  static const cream = Color(0xFFFAF6EE);
  static const green = Color(0xFF22C55E);
}

ThemeData dykLightTheme() => _base(Brightness.light);
ThemeData dykDarkTheme() => _base(Brightness.dark);

ThemeData _base(Brightness b) {
  final dark = b == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    scaffoldBackgroundColor: dark ? DykColors.black : DykColors.cream,
    colorScheme: ColorScheme.fromSeed(
      seedColor: DykColors.yellow,
      brightness: b,
      primary: DykColors.yellow,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: DykColors.yellow,
        foregroundColor: DykColors.black,
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
