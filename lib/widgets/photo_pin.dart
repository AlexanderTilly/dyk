import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Circle-crop an image into a DYK map pin: yellow ring, white inner ring
/// and a pointer tip. Returns null when the image can't be fetched.
Future<Uint8List?> buildPhotoPin(String url) async {
  try {
    final file = await DefaultCacheManager().getSingleFile(url);
    final codec = await ui.instantiateImageCodec(
      await file.readAsBytes(),
      targetWidth: 220,
      targetHeight: 220,
    );
    final img = (await codec.getNextFrame()).image;

    const size = 260.0; // circle 240 + tip
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    const center = Offset(130, 120);
    const radius = 110.0;

    final tip = Path()
      ..moveTo(105, 200)
      ..lineTo(155, 200)
      ..lineTo(130, 252)
      ..close();
    canvas.drawPath(tip, Paint()..color = const Color(0xFFFFC107));

    canvas.drawCircle(
        center, radius + 10, Paint()..color = const Color(0xFFFFC107));
    canvas.drawCircle(center, radius + 3, Paint()..color = Colors.white);

    canvas.save();
    canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: center, radius: radius)));
    final src =
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    final dst = Rect.fromCircle(center: center, radius: radius);
    canvas.drawImageRect(
        img, src, dst, Paint()..filterQuality = FilterQuality.high);
    canvas.restore();

    final out = await rec.endRecording().toImage(size.toInt(), size.toInt());
    final bytes = await out.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}
