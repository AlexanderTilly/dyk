import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../services/dyk_repository.dart';
import '../services/entitlements.dart';
import '../theme/dyk_theme.dart';
import '../widgets/unlock_buttons.dart';
import '../i18n/i18n.dart';
import '../widgets/passim_background.dart';

/// Shown when the app switches to a new city the user hasn't unlocked.
class WelcomeCityScreen extends StatelessWidget {
  final String cityName;
  final String cityId;
  final int priceCents;
  final int hotspotCount;
  final Entitlements entitlements;
  final DykRepositoryBase repo;
  final AuthService authService;

  const WelcomeCityScreen({
    super.key,
    required this.cityName,
    required this.cityId,
    required this.priceCents,
    required this.hotspotCount,
    required this.entitlements,
    required this.repo,
    required this.authService,
  });

  @override
  Widget build(BuildContext context) {
    // Text sits on the artwork/scrim, so it must follow the theme rather
    // than assume a dark photo: onPhoto (white) in dark mode, ink over the
    // light artwork. The 70%/54%/38% variants preserve the existing
    // secondary/tertiary hierarchy on top of whichever base colour applies.
    final dark = Theme.of(context).brightness == Brightness.dark;
    final onArtwork = dark ? PassimColors.onPhoto : PassimColors.ink;
    final onArtworkSecondary = onArtwork.withValues(alpha: 0.7);
    final onArtworkMuted = onArtwork.withValues(alpha: 0.54);
    final onArtworkTertiary = onArtwork.withValues(alpha: 0.38);
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
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
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(tr('maybe_later'),
                          style: TextStyle(color: onArtworkMuted)),
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.place, color: DykColors.yellow, size: 40),
                  const SizedBox(height: 8),
                  Text(tr('welcome_to'),
                      style: TextStyle(
                          color: PassimColors.brand,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                          fontSize: 13)),
                  Text(
                    cityName.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.bebasNeue(
                        color: onArtwork, fontSize: 56, height: 1.0),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    hotspotCount > 0
                        ? '$hotspotCount ${tr('welcome_tagline')}'
                        : tr('welcome_tagline'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: onArtworkSecondary, fontSize: 15, height: 1.4),
                  ),
                  const SizedBox(height: 28),
                  UnlockButtons(
                    cityName: cityName,
                    priceCents: priceCents,
                    cityId: cityId,
                    entitlements: entitlements,
                    repo: repo,
                    authService: authService,
                    onUnlocked: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 12),
                  Text(tr('free_spots_note'),
                      style: TextStyle(color: onArtworkTertiary, fontSize: 12)),
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
