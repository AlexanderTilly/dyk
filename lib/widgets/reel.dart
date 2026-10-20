import 'package:flutter/material.dart';

import '../theme/dyk_theme.dart';

/// One reel of the tour generator: shows [value], and a vertical drag (or a
/// tap on a chevron) steps to the neighbouring entry of [values].
///
/// It does not wrap: the first and last values are hard stops, so a tourist
/// can't spin from 5 km round to 1 km by overshooting.
class Reel<T> extends StatelessWidget {
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

  static const _dragThreshold = 24.0;

  void _step(int delta) {
    final i = values.indexOf(value) + delta;
    if (i < 0 || i >= values.length) return;
    onChanged(values[i]);
  }

  @override
  Widget build(BuildContext context) {
    var dragged = 0.0;
    final i = values.indexOf(value);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) => dragged = 0,
      onVerticalDragUpdate: (d) => dragged += d.delta.dy,
      // One step per gesture, decided on release, so a long fling can't
      // skip several positions or fire onChanged repeatedly.
      onVerticalDragEnd: (_) {
        if (dragged <= -_dragThreshold) _step(1);
        if (dragged >= _dragThreshold) _step(-1);
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
            _chevron(Icons.keyboard_arrow_up, i < values.length - 1, 1),
            Text(
              label(value),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: PassimColors.brand,
                fontSize: 20,
                fontWeight: FontWeight.w900,
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
