import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../services/dyk_repository.dart';
import '../services/entitlements.dart';
import '../theme/dyk_theme.dart';
import '../widgets/unlock_buttons.dart';
import '../i18n/i18n.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/landing_background.jpg'),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        child: Container(
          color: Colors.black.withValues(alpha: 0.72),
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
                          style: const TextStyle(color: Colors.white54)),
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
                        color: Colors.white, fontSize: 56, height: 1.0),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    hotspotCount > 0
                        ? '$hotspotCount ${tr('welcome_tagline')}'
                        : tr('welcome_tagline'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 15, height: 1.4),
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
                      style: const TextStyle(color: Colors.white38, fontSize: 12)),
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
