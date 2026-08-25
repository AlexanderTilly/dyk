import 'package:flutter/material.dart';

import '../models/internal_ad.dart';
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
                      Container(color: const Color(0xFF2A2A2A)),
                ),
              )
            else
              Positioned.fill(child: Container(color: const Color(0xFF2A2A2A))),
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
                child: const Text('FEATURED',
                    style: TextStyle(
                        color: Colors.white70,
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
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            )),
                        if (ad.subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(ad.subtitle!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12.5)),
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
