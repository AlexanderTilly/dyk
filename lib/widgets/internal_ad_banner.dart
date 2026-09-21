import 'package:flutter/material.dart';

import '../models/internal_ad.dart';
import '../screens/navigate_screen.dart';
import '../services/ad_events.dart';
import '../theme/dyk_theme.dart';

/// Compact GPS-targeted internal ad shown on the Explore tab.
class InternalAdBanner extends StatelessWidget {
  final InternalAd ad;
  const InternalAdBanner({super.key, required this.ad});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {}, // hook up link/landing later
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // Background image
            if (ad.imageUrl != null)
              Positioned.fill(
                child: Image.network(
                  ad.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: PassimColors.surface),
                ),
              )
            else
              Positioned.fill(child: Container(color: PassimColors.surface)),
            // Dark scrim for legibility
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.black.withValues(alpha: 0.25),
                    ],
                  ),
                ),
              ),
            ),
            // "Sponsored" tag
            Positioned(
              top: 10,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text('FEATURED',
                    style: TextStyle(
                        // Tag sits on the photo scrim, stays white in both themes.
                        color: PassimColors.onPhoto.withValues(alpha: 0.7),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5)),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (ad.iconUrl != null)
                    Image.network(ad.iconUrl!, width: 56, height: 56,
                        errorBuilder: (_, __, ___) => const SizedBox(width: 56)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ad.title.toUpperCase(),
                            style: const TextStyle(
                              color: PassimColors.onPhoto, // title over photo scrim
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            )),
                        if (ad.subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(ad.subtitle!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: PassimColors.onPhoto.withValues(alpha: 0.7),
                                  fontSize: 12.5)),
                        ],
                        if (ad.hasDestination) ...[
                          const SizedBox(height: 10),
                          _TakeMeThere(ad: ad),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_ios,
                      color: DykColors.yellow, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Walks the tourist to the advertiser's door.
///
/// Shown only when the advertiser gave a door — an ad without one would
/// otherwise navigate to the centre of its display radius, which is a
/// different place and often a different street.
class _TakeMeThere extends StatelessWidget {
  final InternalAd ad;
  const _TakeMeThere({required this.ad});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Stops the tap reaching the banner underneath, which has its own
      // action.
      onTap: () async {
        // Counted before navigating, not after: the screen may never be
        // closed, and the intent has already happened.
        await AdEvents.directionsTapped(ad.id);
        if (!context.mounted) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => NavigateScreen(
            destination: NavDestination(
              lat: ad.destLat!,
              lng: ad.destLng!,
              name: ad.title,
              imageUrl: ad.imageUrl,
              arrivalMeters: AdEvents.arrivalMeters,
            ),
          ),
        ));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: PassimColors.brand,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_walk,
                size: 15, color: PassimColors.ink),
            const SizedBox(width: 5),
            Text(
              ad.destLabel?.isNotEmpty == true
                  ? ad.destLabel!
                  : 'Take me there',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                // On the amber pill, so ink in both themes.
                color: PassimColors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
