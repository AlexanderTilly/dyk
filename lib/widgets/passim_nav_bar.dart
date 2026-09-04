import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/dyk_theme.dart';

class PassimNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const PassimNavItem(this.icon, this.activeIcon, this.label);
}

/// Floating glass navigation bar.
///
/// Sits above the content rather than sealing off the bottom of the screen,
/// with the page blurred behind it — so the artwork and photos still read
/// through, and the bar feels like it belongs to the content instead of
/// cutting it off. Requires `extendBody: true` on the Scaffold, otherwise
/// there is nothing behind the blur to see.
class PassimNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<PassimNavItem> items;

  const PassimNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: DecoratedBox(
            decoration: BoxDecoration(
              // Translucent so the blur is visible; without any tint the text
              // loses contrast over bright photos.
              color: PassimColors.ink.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.10),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (var i = 0; i < items.length; i++)
                      _NavButton(
                        item: items[i],
                        selected: i == currentIndex,
                        onTap: () => onTap(i),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final PassimNavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colour = selected ? PassimColors.brand : Colors.white70;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            // A soft amber pill marks the active tab, the way the icon alone
            // cannot once everything is the same size.
            color: selected
                ? PassimColors.brand.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? item.activeIcon : item.icon,
                  size: 23, color: colour),
              const SizedBox(height: 3),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                  letterSpacing: 0.3,
                  color: colour,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
