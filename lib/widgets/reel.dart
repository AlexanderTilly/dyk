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

  /// Horizontal space the reel box takes besides the label: padding 8 + 8
  /// and the 1.5 + 1.5 border.
  static const chromeWidth = 19.0;

  /// [base] is the ambient style (`DefaultTextStyle.of(context).style`), so
  /// measuring uses the same font the rendered Text will.
  static TextStyle labelStyle(double size, [TextStyle? base]) =>
      (base ?? const TextStyle()).merge(TextStyle(
        color: PassimColors.brand,
        fontSize: size,
        fontWeight: FontWeight.w900,
      ));

  static double _width(
          String t, double size, TextScaler scaler, TextStyle? base) =>
      (TextPainter(
        text: TextSpan(text: t, style: labelStyle(size, base)),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout())
          .width;

  /// Width of the widest single word among [labels] at [size], so a column
  /// can be sized to keep its longest word whole.
  static double longestWord(
      Iterable<String> labels, double size, TextScaler scaler,
      [TextStyle? base]) {
    var widest = 0.0;
    for (final l in labels) {
      for (final w in l.split(' ')) {
        final x = _width(w, size, scaler, base);
        if (x > widest) widest = x;
      }
    }
    return widest;
  }

  /// Narrowest column width in which every one of [labels] fits in
  /// [maxLines] lines at [size] without breaking a word.
  static double fitWidth(
      Iterable<String> labels, double size, int maxLines, TextScaler scaler,
      [TextStyle? base]) {
    var need = longestWord(labels, size, scaler, base);
    for (final l in labels) {
      bool fits(double w) => !(TextPainter(
            text: TextSpan(text: l, style: labelStyle(size, base)),
            textDirection: TextDirection.ltr,
            textScaler: scaler,
            maxLines: maxLines,
          )..layout(maxWidth: w))
              .didExceedMaxLines;
      var lo = need, hi = widestLine([l], size, scaler, base) + 1;
      if (fits(lo)) continue;
      while (hi - lo > 0.5) {
        final mid = (lo + hi) / 2;
        if (fits(mid)) {
          hi = mid;
        } else {
          lo = mid;
        }
      }
      need = hi;
    }
    return need;
  }

  /// Width of the widest label on one line at [size].
  static double widestLine(
      Iterable<String> labels, double size, TextScaler scaler,
      [TextStyle? base]) {
    var widest = 0.0;
    for (final l in labels) {
      final x = _width(l, size, scaler, base);
      if (x > widest) widest = x;
    }
    return widest;
  }

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
      final base = DefaultTextStyle.of(context).style;
      TextStyle style(double size) => Reel.labelStyle(size, base);
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

        final longestWord = Reel.longestWord([text], size, scaler, base);
        return longestWord <= c.maxWidth &&
            measure(text, widget.maxLines) <= c.maxWidth;
      }

      var size = Reel.labelSize;
      while (size > Reel.labelFloor && !fits(size)) {
        size -= 1;
      }
      // A word wider than the column even at the floor is never split
      // across lines: it stays on one line and is ellipsised.
      final wordFits =
          Reel.longestWord([text], size, scaler, base) <= c.maxWidth;
      return Text(
        text,
        maxLines: wordFits ? widget.maxLines : 1,
        softWrap: wordFits,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: style(size),
      );
    });
  }
}
