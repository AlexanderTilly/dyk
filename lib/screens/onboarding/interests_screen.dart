import 'package:flutter/material.dart';
import '../../i18n/i18n.dart';

import '../../theme/dyk_theme.dart';
import '../../widgets/category_badge.dart';
import '../../widgets/dyk_page_route.dart';
import '../../widgets/passim_background.dart';
import 'consent_screen.dart';

class InterestOption {
  final String key;
  final String emoji;
  final String title;
  final String description;
  const InterestOption(this.key, this.emoji, this.title, this.description);
}

// Built per access so titles/descriptions follow the chosen language.
List<InterestOption> get dykInterestOptions => [
      InterestOption('history', '🏛️', tr('cat_history'), tr('int_history_sub')),
      InterestOption('otium', '🌿', tr('cat_otium'), tr('int_otium_sub')),
      InterestOption(
          'headline', '📖', tr('cat_headline'), tr('int_headline_sub')),
      InterestOption('hotdeal', '🔥', tr('cat_hotdeal'), tr('int_hotdeal_sub')),
    ];

class InterestsScreen extends StatefulWidget {
  final VoidCallback onFinished;
  final void Function(Set<String>)? onInterestsChosen;

  const InterestsScreen({
    super.key,
    required this.onFinished,
    this.onInterestsChosen,
  });

  @override
  State<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends State<InterestsScreen> {
  final Set<String> _selected = {
    'history',
    'otium',
    'headline',
    'hotdeal',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(passimArtwork(context)),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          // The shared scrim, so this screen flips with the theme instead of
          // staying black under a light app.
          decoration: passimScrim(context),
          child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(tr('ob_interests_title'),
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(tr('ob_interests_sub')),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  children: [
                    for (final opt in dykInterestOptions)
                      _InterestCard(
                        option: opt,
                        selected: _selected.contains(opt.key),
                        onTap: () => setState(() {
                          _selected.contains(opt.key)
                              ? _selected.remove(opt.key)
                              : _selected.add(opt.key);
                        }),
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () {
                          widget.onInterestsChosen?.call(_selected);
                          Navigator.of(context).push(
                            DykPageRoute(
                              page: ConsentScreen(
                                  onFinished: widget.onFinished),
                            ),
                          );
                        },
                  child: Text(tr('continue_btn')),
                ),
              ),
            ],
          ),
        ),
        ),
        ),
      ),
    );
  }
}

class _InterestCard extends StatelessWidget {
  final InterestOption option;
  final bool selected;
  final VoidCallback onTap;

  const _InterestCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // The card is an opaque surface, so its text takes the surface's contrast
    // rather than the artwork's.
    final onCard = dark ? PassimColors.onPhoto : PassimColors.ink;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.0 : 0.97,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // Fully opaque so the artwork never bleeds through the content —
          // but the theme's surface, not a fixed grey that only worked when
          // the app was dark-only.
          color: dark ? PassimColors.surface : PassimColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? PassimColors.brand
                : PassimColors.ink.withValues(alpha: dark ? 0.30 : 0.10),
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: PassimColors.ink.withValues(alpha: dark ? 0.45 : 0.14),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
            if (selected)
              BoxShadow(
                color: DykColors.yellow.withValues(alpha: 0.35),
                blurRadius: 18,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Row(
          children: [
            CategoryBadge(category: option.key, size: 52),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(option.title,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: onCard)),
                  const SizedBox(height: 2),
                  Text(option.description,
                      style: TextStyle(
                          fontSize: 12,
                          color: onCard.withValues(alpha: 0.70))),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected
                  ? PassimColors.brand
                  : onCard.withValues(alpha: 0.38),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
