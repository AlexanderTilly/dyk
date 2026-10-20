import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../models/themes.dart';
import '../services/dyk_repository.dart';
import '../theme/dyk_theme.dart';
import '../widgets/reel.dart';

/// The theme that only makes sense for the long round. The gates ring the old
/// city and the castles lie well outside it, so under 5 km it is a march
/// between landmarks, not a walk.
const _wallsGates = 'walls_gates';
const _wallsGatesMinKm = 5;

const tourDistancesKm = [1, 2, 3, 5];
const tourShapes = ['loop', 'one_way'];

/// The slot machine: Distance, Shape and Theme reels and a lever. It makes no
/// network calls; [onGenerate] receives the three values on a pull.
class TourGeneratorScreen extends StatefulWidget {
  final String? citypackId;
  final Set<String> narratedCities;
  final void Function(int km, String shape, String theme) onGenerate;
  final bool busy;

  const TourGeneratorScreen({
    super.key,
    required this.citypackId,
    required this.narratedCities,
    required this.onGenerate,
    this.busy = false,
  });

  @override
  State<TourGeneratorScreen> createState() => TourGeneratorScreenState();
}

class TourGeneratorScreenState extends State<TourGeneratorScreen> {
  int _km = 2;
  String _shape = 'loop';
  String _theme = tourThemes.first;

  int get distanceKm => _km;
  String get shape => _shape;
  String get theme => _theme;

  /// Themes the reel may show right now. walls_gates only at 5 km.
  List<String> get availableThemes => [
        for (final t in tourThemes)
          if (t != _wallsGates || _km >= _wallsGatesMinKm) t
      ];

  void selectTheme(String t) {
    if (!availableThemes.contains(t)) return;
    setState(() => _theme = t);
  }

  void _setDistance(int km) {
    setState(() {
      _km = km;
      // A pull must never ask for an impossible combination. If the current
      // theme just left the reel, fall back to the first remaining theme.
      if (!availableThemes.contains(_theme)) {
        _theme = availableThemes.first;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!generatorAvailable(widget.citypackId, widget.narratedCities)) {
      return const SizedBox.shrink();
    }
    return Container(
      color: PassimColors.ink,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Reel<int>(
                  key: const Key('reel_distance'),
                  values: tourDistancesKm,
                  value: _km,
                  onChanged: _setDistance,
                  label: (v) => '$v km',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Reel<String>(
                  key: const Key('reel_shape'),
                  values: tourShapes,
                  value: _shape,
                  onChanged: (v) => setState(() => _shape = v),
                  label: (v) => tr('shape_$v'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Reel<String>(
                  key: const Key('reel_theme'),
                  values: availableThemes,
                  value: _theme,
                  onChanged: selectTheme,
                  label: themeLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('lever'),
              style: FilledButton.styleFrom(
                backgroundColor: PassimColors.brand,
                foregroundColor: PassimColors.ink,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: widget.busy
                  ? null
                  : () => widget.onGenerate(_km, _shape, _theme),
              child: Text(
                tr(widget.busy ? 'generating_tour' : 'generate_tour'),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
