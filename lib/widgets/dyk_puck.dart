import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The DYK location puck: soft gold halo, white ring, gold core and a
/// heading wedge (the SDK rotates the image with the compass bearing).
Future<Uint8List> buildDykPuck() async {
  const size = 140;
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  const center = Offset(70, 70);
  canvas.drawCircle(
      center,
      66,
      Paint()
        ..shader = ui.Gradient.radial(center, 66, [
          const Color(0xFFFFC107).withValues(alpha: 0.35),
          const Color(0xFFFFC107).withValues(alpha: 0.0),
        ]));
  final wedge = Path()
    ..moveTo(70, 14)
    ..lineTo(56, 44)
    ..lineTo(84, 44)
    ..close();
  canvas.drawPath(wedge, Paint()..color = const Color(0xFFFFC107));
  canvas.drawPath(
      wedge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF1A1A1A));
  canvas.drawCircle(center, 27, Paint()..color = Colors.white);
  canvas.drawCircle(center, 21, Paint()..color = const Color(0xFFFFC107));
  canvas.drawCircle(center, 7, Paint()..color = const Color(0xFF1A1A1A));
  final img = await rec.endRecording().toImage(size, size);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}
