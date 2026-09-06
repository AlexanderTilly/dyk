import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../services/dyk_repository.dart';
import '../services/entitlements.dart';
import '../widgets/unlock_buttons.dart';
import '../i18n/i18n.dart';
import '../widgets/passim_background.dart';
import '../theme/dyk_theme.dart';

/// "View Plans" — the real unlock flow: per-city or Premium (all cities).
class PremiumScreen extends StatelessWidget {
  final Entitlements entitlements;
  final DykRepositoryBase repo;
  final AuthService authService;
  final String cityId;
  final String cityName;
  final int cityPriceCents;

  const PremiumScreen({
    super.key,
    required this.entitlements,
    required this.repo,
    required this.authService,
    required this.cityId,
    required this.cityName,
    required this.cityPriceCents,
  });

  @override
  Widget build(BuildContext context) {
    // Text sits on the artwork/scrim, so it must follow the theme rather
    // than assume a dark photo: onPhoto (white) in dark mode, ink over the
    // light artwork. The 70%/38% variants preserve the existing secondary
    // and tertiary hierarchy on top of whichever base colour applies.
    final dark = Theme.of(context).brightness == Brightness.dark;
    final onArtwork = dark ? PassimColors.onPhoto : PassimColors.ink;
    final onArtworkSecondary = onArtwork.withValues(alpha: 0.7);
    final onArtworkTertiary = onArtwork.withValues(alpha: 0.38);

    Widget perk(String emoji, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(text,
                      style: TextStyle(
                          color: onArtworkSecondary, fontSize: 15))),
            ],
          ),
        );

    return Scaffold(
      // Follows the theme's scaffold background instead of a hardcoded
      // dark value, so light mode doesn't show a black flash behind the
      // scrim/artwork.
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(passimArtwork(context)),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        child: Container(
          decoration: passimScrim(context),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: Icon(Icons.arrow_back, color: onArtwork),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const Spacer(),
                  const Center(
                      child: Text('👑', style: TextStyle(fontSize: 52))),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(tr('go_premium_caps'),
                        style: GoogleFonts.bebasNeue(
                            color: onArtwork, fontSize: 48, height: 1.0)),
                  ),
                  const SizedBox(height: 14),
                  perk('🌍', tr('perk_cities')),
                  perk('🎧', tr('perk_stories')),
                  perk('🚶', tr('perk_tours')),
                  perk('🔔', tr('perk_offers')),
                  const SizedBox(height: 26),
                  UnlockButtons(
                    cityName: cityName,
                    priceCents: cityPriceCents,
                    cityId: cityId,
                    entitlements: entitlements,
                    repo: repo,
                    authService: authService,
                    onUnlocked: () {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(tr('unlocked_enjoy'))),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(tr('free_spots_note'),
                        style: TextStyle(color: onArtworkTertiary, fontSize: 12)),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
