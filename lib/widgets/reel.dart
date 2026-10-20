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

  const Reel({
    super.key,
    required this.values,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  /// Finger travel that steps one notch. Measured on this Flutter version:
  /// the recogniser reports the full travel including the touch slop (a
  /// 40 px move reports 40 px), so this is what the finger actually moves.
  static const dragThreshold = 24.0;

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
            // Shrink rather than overflow: a long word can't be broken.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                widget.label(widget.value),
                maxLines: 1,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: PassimColors.brand,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
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
}
