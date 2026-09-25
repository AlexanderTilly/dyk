import 'package:flutter/material.dart';

import '../theme/dyk_theme.dart';

/// Badge image per category.
///
/// The four Explore categories use flat amber line art on a transparent
/// background, so this draws the navy disc they sit on. The older sticker
/// badges — subcategories, city packs, the pickpocket warning — carry their
/// own painted background and are drawn untouched; giving those a disc too
/// would put a circle inside a circle.
class CategoryBadge extends StatelessWidget {
  final String category;
  final double size;

  const CategoryBadge({super.key, required this.category, this.size = 48});

  /// Transparent line art. Needs a disc behind it.
  static const _lineArt = {
    'history': 'assets/images/badges/explore_history.png',
    'otium': 'assets/images/badges/explore_otium.png',
    'headline': 'assets/images/badges/explore_headline.png',
    'hotdeal': 'assets/images/badges/explore_hotdeal.png',
  };

  /// Stickers that already contain their own background.
  static const _stickers = {
    'funfact': 'assets/images/badges/funfact.png',
    'citypack': 'assets/images/badges/citypack.png',
  };

  static const _emojiFallback = {
    'history': '🏛️',
    'otium': '🌿',
    'funfact': '💡',
    'headline': '📖',
    'hotdeal': '🔥',
    'citypack': '📦',
  };

  @override
  Widget build(BuildContext context) {
    final art = _lineArt[category];
    if (art != null) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          // Fixed navy in both themes. The amber art needs a dark ground to
          // read at all, and these badges also sit over photos and the map
          // where the theme's own surface would be the wrong answer.
          color: PassimColors.ink,
          shape: BoxShape.circle,
        ),
        // The art is already normalised to a consistent share of its canvas
        // by tool/prepare_category_badges.py, so no per-icon padding here.
        child: Image.asset(art, fit: BoxFit.contain),
      );
    }

    final sticker = _stickers[category];
    if (sticker != null) {
      return Image.asset(sticker,
          width: size, height: size, fit: BoxFit.contain);
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
