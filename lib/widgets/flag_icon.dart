import 'package:flutter/material.dart';

/// Small painted flag for the language picker. Painted (not emoji) because
/// Catalonia has no emoji flag and emoji flags render inconsistently.
class FlagIcon extends StatelessWidget {
  final String code; // en | es | ca | de
  final double width;

  const FlagIcon({super.key, required this.code, this.width = 28});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: width,
        height: width * 0.7,
        child: CustomPaint(painter: _FlagPainter(code)),
      ),
    );
  }
}

class _FlagPainter extends CustomPainter {
  final String code;
  _FlagPainter(this.code);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final p = Paint();
    switch (code) {
      case 'es': // Spain: red / yellow (double) / red
        p.color = const Color(0xFFAA151B);
        canvas.drawRect(Rect.fromLTWH(0, 0, w, h / 4), p);
        canvas.drawRect(Rect.fromLTWH(0, 3 * h / 4, w, h / 4), p);
        p.color = const Color(0xFFF1BF00);
        canvas.drawRect(Rect.fromLTWH(0, h / 4, w, h / 2), p);
        break;
      case 'ca': // Senyera: yellow with four red bars
        p.color = const Color(0xFFFCDD09);
        canvas.drawRect(Rect.fromLTWH(0, 0, w, h), p);
        p.color = const Color(0xFFDA121A);
        final bar = h / 9;
        for (var i = 0; i < 4; i++) {
          canvas.drawRect(
              Rect.fromLTWH(0, bar * (2 * i + 1), w, bar), p);
        }
        break;
      case 'de': // Germany: black / red / gold
        p.color = Colors.black;
        canvas.drawRect(Rect.fromLTWH(0, 0, w, h / 3), p);
        p.color = const Color(0xFFDD0000);
        canvas.drawRect(Rect.fromLTWH(0, h / 3, w, h / 3), p);
        p.color = const Color(0xFFFFCE00);
        canvas.drawRect(Rect.fromLTWH(0, 2 * h / 3, w, h / 3), p);
        break;
      default: // Union Jack (simplified but recognizable)
        p.color = const Color(0xFF012169);
        canvas.drawRect(Rect.fromLTWH(0, 0, w, h), p);
        // White diagonals.
        p
          ..color = Colors.white
          ..strokeWidth = h * 0.28
          ..style = PaintingStyle.stroke;
        canvas.drawLine(Offset.zero, Offset(w, h), p);
        canvas.drawLine(Offset(w, 0), Offset(0, h), p);
        // Red diagonals.
        p
          ..color = const Color(0xFFC8102E)
          ..strokeWidth = h * 0.10;
        canvas.drawLine(Offset.zero, Offset(w, h), p);
        canvas.drawLine(Offset(w, 0), Offset(0, h), p);
        // White cross.
        p
          ..color = Colors.white
          ..strokeWidth = h * 0.36;
        canvas.drawLine(Offset(w / 2, 0), Offset(w / 2, h), p);
        canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2), p);
        // Red cross.
        p
          ..color = const Color(0xFFC8102E)
          ..strokeWidth = h * 0.20;
        canvas.drawLine(Offset(w / 2, 0), Offset(w / 2, h), p);
        canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2), p);
    }
  }

  @override
  bool shouldRepaint(_FlagPainter old) => old.code != code;
}
