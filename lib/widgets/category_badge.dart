import 'package:flutter/material.dart';

/// Sticker badge image per category, with emoji fallback when the
/// asset hasn't been delivered yet (currently: history).
class CategoryBadge extends StatelessWidget {
  final String category;
  final double size;

  const CategoryBadge({super.key, required this.category, this.size = 48});

  static const _assets = {
    'funfact': 'assets/images/badges/funfact.png',
    'headline': 'assets/images/badges/headline.png',
    'hotdeal': 'assets/images/badges/hotdeal.png',
    'citypack': 'assets/images/badges/citypack.png',
  };

  static const _emojiFallback = {
    'history': '🏛️',
    'funfact': '💡',
    'headline': '📰',
    'hotdeal': '🔥',
    'citypack': '📦',
  };

  @override
  Widget build(BuildContext context) {
    final asset = _assets[category];
    if (asset != null) {
      return Image.asset(asset, width: size, height: size, fit: BoxFit.contain);
    }
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(
          _emojiFallback[category] ?? '📍',
          style: TextStyle(fontSize: size * 0.6),
        ),
      ),
    );
  }
}
