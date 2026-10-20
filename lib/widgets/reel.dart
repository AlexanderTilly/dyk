import 'package:flutter/material.dart';

import '../theme/dyk_theme.dart';

/// One reel of the tour generator: shows [value], and a vertical drag (or a
/// tap on a chevron) steps to the neighbouring entry of [values].
///
/// It does not wrap: the first and last values are hard stops, so a tourist
/// can't spin from 5 km round to 1 km by overshooting.
class Reel<T> extends StatefulWidget {
  final List<T> values;
  final T value;
  final ValueChanged<T> onChanged;
  final String Function(T) label;

  /// Lines the label may wrap to before it is shrunk or ellipsised.
  final int maxLines;

  const Reel({
    super.key,
    required this.values,
    required this.value,
    required this.onChanged,
    required this.label,
    this.maxLines = 1,
  });

  /// Finger travel that steps one notch. Measured on this Flutter version:
  /// the recogniser reports the full travel including the touch slop (a
  /// 40 px move reports 40 px), so this is what the finger actually moves.
  static const dragThreshold = 24.0;

  /// Design size of the label, and the smallest it is ever shrunk to.
  /// Past the floor the label is ellipsised rather than made unreadable.
  static const labelSize = 20.0;
  static const labelFloor = 14.0;

  @override
  State<Reel<T>> createState() => _ReelState<T>();
}

class _ReelState<T> extends State<Reel<T>> {
  // A field, not a build local: a rebuild mid-drag must not lose the delta.
  double _dragged = 0;

  void _step(int delta) {
    final i = widget.values.indexOf(widget.value) + delta;
    if (i < 0 || i >= widget.values.length) return;
    widget.onChanged(widget.values[i]);
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.values.indexOf(widget.value);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) => _dragged = 0,
      onVerticalDragUpdate: (d) => _dragged += d.delta.dy,
      // One step per gesture, decided on release, so a long fling can't
      // skip several positions or fire onChanged repeatedly.
      onVerticalDragEnd: (_) {
        if (_dragged <= -Reel.dragThreshold) _step(1);
        if (_dragged >= Reel.dragThreshold) _step(-1);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: PassimColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PassimColors.brand, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _chevron(Icons.keyboard_arrow_up, i < widget.values.length - 1, 1),
            _label(context),
            _chevron(Icons.keyboard_arrow_down, i > 0, -1),
          ],
        ),
      ),
    );
  }

  Widget _chevron(IconData icon, bool enabled, int delta) => InkWell(
        onTap: enabled ? () => _step(delta) : null,
        child: Icon(icon,
            color: PassimColors.brand.withValues(alpha: enabled ? 1 : 0.2)),
      );

  /// 20 px weight 900 whenever it fits in [Reel.maxLines] lines without
  /// breaking a word; otherwise shrinks one px at a time down to the floor,
  /// then ellipsises.
  Widget _label(BuildContext context) {
    final text = widget.label(widget.value);
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(builder: (context, c) {
      TextStyle style(double size) => TextStyle(
            color: PassimColors.brand,
            fontSize: size,
            fontWeight: FontWeight.w900,
          );
      bool fits(double size) {
        double measure(String t, int lines) {
          final tp = TextPainter(
            text: TextSpan(text: t, style: style(size)),
            textDirection: TextDirection.ltr,
            textScaler: scaler,
            maxLines: lines,
          )..layout(maxWidth: c.maxWidth);
          return tp.didExceedMaxLines ? double.infinity : tp.width;
        }

        final longestWord = text
            .split(' ')
            .map((w) => TextPainter(
                  text: TextSpan(text: w, style: style(size)),
                  textDirection: TextDirection.ltr,
                  textScaler: scaler,
                )..layout())
            .map((tp) => tp.width)
            .fold<double>(0, (a, b) => a > b ? a : b);
        return longestWord <= c.maxWidth &&
            measure(text, widget.maxLines) <= c.maxWidth;
      }

      var size = Reel.labelSize;
      while (size > Reel.labelFloor && !fits(size)) {
        size -= 1;
      }
      return Text(
        text,
        maxLines: widget.maxLines,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: style(size),
      );
    });
  }
}
