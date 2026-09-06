import 'package:flutter/material.dart';

import '../theme/dyk_theme.dart';

/// The branded backdrop: the Passim artwork under a scrim.
///
/// The artwork is bright enough on its own to swallow text and the wordmark,
/// so every screen puts the same fade over it — and the fade runs towards the
/// theme's own background colour, so the polarity flips with the mode instead
/// of leaving a navy haze over a light app.
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
    return DecoratedBox(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(passimArtwork(context)),
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
      ),
      child: DecoratedBox(
        decoration: passimScrim(context, strength: scrim),
        child: child,
      ),
    );
  }
}

enum Scrim { light, heavy }

/// Which artwork file matches the current theme.
String passimArtwork(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? 'assets/images/landing_background.jpg'
        : 'assets/images/landing_background_light.jpg';

/// The wordmark.
///
/// The asset follows the theme rather than the caller: the cream logo is
/// invisible on sand, and there are five call sites that would each have to
/// remember. [wordmarkOnly] drops the pin — the full logo already contains
/// one, so anything drawing its own pin must use this.
class PassimLogo extends StatelessWidget {
  final double height;
  final bool wordmarkOnly;

  const PassimLogo({super.key, this.height = 40, this.wordmarkOnly = false});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final asset = switch ((wordmarkOnly, dark)) {
      (true, true) => 'assets/images/passim_wordmark.png',
      (true, false) => 'assets/images/passim_wordmark_light.png',
      (false, true) => 'assets/images/passim_logo.png',
      (false, false) => 'assets/images/passim_logo_light.png',
    };
    return Image.asset(asset, height: height, fit: BoxFit.contain);
  }
}

/// The scrim as a decoration, for screens that already own their background
/// container.
///
/// Takes a context because it has no other way to know the brightness, and a
/// scrim that does not flip is exactly the navy haze this work is removing.
BoxDecoration passimScrim(BuildContext context,
    {Scrim strength = Scrim.heavy}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final (top, bottom) = switch (strength) {
    Scrim.light => (0.05, 0.30),
    // Light mode needs a heavier veil: sand over a bright photo separates
    // less than navy does, so the same alpha would leave text sitting on
    // texture.
    Scrim.heavy => dark ? (0.25, 0.62) : (0.45, 0.80),
  };
  final base = dark ? PassimColors.ink : PassimColors.sand;
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [base.withValues(alpha: top), base.withValues(alpha: bottom)],
    ),
  );
}
