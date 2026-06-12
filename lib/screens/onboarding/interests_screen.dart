import 'package:flutter/material.dart';

import '../../theme/dyk_theme.dart';
import '../../widgets/category_badge.dart';
import '../../widgets/dyk_page_route.dart';
import 'location_screen.dart';

class InterestOption {
  final String key;
  final String emoji;
  final String title;
  final String description;
  const InterestOption(this.key, this.emoji, this.title, this.description);
}

const dykInterestOptions = [
  InterestOption('history', '🏛️', 'History',
      'Ancient landmarks, hidden stories and historical moments.'),
  InterestOption('funfact', '💡', 'Fun Facts',
      'Unexpected stories and surprising details most visitors never discover.'),
  InterestOption('headline', '📰', 'Headlines',
      'Important events, famous people and moments that shaped the city.'),
  InterestOption('hotdeal', '🔥', 'Hot Deals',
      'Exclusive discounts and offers from places around you.'),
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
  final Set<String> _selected = {'history', 'funfact', 'headline', 'hotdeal'};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/landing_background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          // Dark scrim so text and cards stay readable over the artwork.
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.55),
                Colors.black.withValues(alpha: 0.35),
                Colors.black.withValues(alpha: 0.65),
              ],
            ),
          ),
          child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text('Choose Your Interests',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: const [
                      Shadow(color: Colors.black87, blurRadius: 8),
                    ],
                  )),
              const SizedBox(height: 8),
              const Text(
                "Make it yours. Pick one or pick them all. You'll only be notified about what's interesting to you.",
                style: TextStyle(
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 6)],
                ),
              ),
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
                              page: LocationScreen(
                                  onFinished: widget.onFinished),
                            ),
                          );
                        },
                  child: const Text('CONTINUE'),
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
          // Solid card so it reads clearly over the busy background art.
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? DykColors.yellow : Colors.black12,
            width: 2.5,
          ),
          boxShadow: [
            const BoxShadow(
              color: Colors.black45,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
            if (selected)
              BoxShadow(
                color: DykColors.yellow.withValues(alpha: 0.45),
                blurRadius: 16,
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
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Color(0xFF1A1A1A))),
                  const SizedBox(height: 2),
                  Text(option.description,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? DykColors.yellow : Colors.grey,
            ),
          ],
        ),
        ),
      ),
    );
  }
}
