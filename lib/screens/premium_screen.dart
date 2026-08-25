import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../services/dyk_repository.dart';
import '../services/entitlements.dart';
import '../widgets/unlock_buttons.dart';
import '../i18n/i18n.dart';

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
    Widget perk(String emoji, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(text,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 15))),
            ],
          ),
        );

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/landing_background.png'),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        child: Container(
          color: Colors.black.withValues(alpha: 0.75),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
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
                            color: Colors.white, fontSize: 48, height: 1.0)),
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
                        style: const TextStyle(color: Colors.white38, fontSize: 12)),
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
