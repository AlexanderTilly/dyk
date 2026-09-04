import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/dyk_theme.dart';

/// The branded backdrop: the Passim artwork under a deep navy scrim.
///
/// The artwork is bright enough on its own to swallow white text and the
/// wordmark, so every screen puts the same ink-coloured fade over it — darker
/// towards the bottom, where content sits. Having it in one place means the
/// screens can never drift apart again.
class PassimBackground extends StatelessWidget {
  final Widget child;

  /// How heavy the scrim is. [Scrim.light] keeps the artwork legible on
  /// splash and onboarding; [Scrim.heavy] is for screens full of text.
  final Scrim scrim;

  const PassimBackground({
    super.key,
    required this.child,
    this.scrim = Scrim.heavy,
  });

  @override
  Widget build(BuildContext context) {
    final (top, bottom) = switch (scrim) {
      Scrim.light => (0.05, 0.30),
      Scrim.heavy => (0.25, 0.62),
    };
    return DecoratedBox(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/landing_background.jpg'),
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              PassimColors.ink.withValues(alpha: top),
              PassimColors.ink.withValues(alpha: bottom),
            ],
          ),
        ),
        child: child,
      ),
    );
  }
}

enum Scrim { light, heavy }

/// The wordmark with a soft amber glow behind it.
///
/// A BoxShadow would halo the image's bounding box; blurring a tinted copy of
/// the logo itself makes the glow follow the letterforms and the pin.
class PassimLogo extends StatelessWidget {
  final double height;
  final double glow;

  const PassimLogo({super.key, this.height = 40, this.glow = 10});

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/images/passim_logo.png',
      height: height,
      fit: BoxFit.contain,
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: glow, sigmaY: glow),
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              PassimColors.brand.withValues(alpha: 0.55),
              BlendMode.srcATop,
            ),
            child: image,
          ),
        ),
        image,
      ],
    );
  }
}

/// The same navy scrim as a decoration, for screens that already own their
/// background container.
BoxDecoration passimScrim({Scrim strength = Scrim.heavy}) {
  final (top, bottom) = switch (strength) {
    Scrim.light => (0.05, 0.30),
    Scrim.heavy => (0.25, 0.62),
  };
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        PassimColors.ink.withValues(alpha: top),
        PassimColors.ink.withValues(alpha: bottom),
      ],
    ),
  );
}
