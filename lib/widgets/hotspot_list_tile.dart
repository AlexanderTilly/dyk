import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../models/hotspot.dart';
import 'category_badge.dart';
import '../theme/dyk_theme.dart';

/// Photo row with a small category badge — same look as the Nearby list.
class HotspotListTile extends StatelessWidget {
  final Hotspot hotspot;
  final VoidCallback onTap;

  const HotspotListTile({
    super.key,
    required this.hotspot,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final img = hotspot.images.isNotEmpty ? hotspot.images.first : null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: dark ? PassimColors.surface : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: img != null
                  ? Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: img,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Center(
                                child: CategoryBadge(
                                    category: hotspot.category, size: 44)),
                          ),
                        ),
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: Container(
                            padding: const EdgeInsets.all(1.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: dark
                                      ? PassimColors.ink
                                      : Colors.white,
                                  width: 2),
                            ),
                            child: CategoryBadge(
                                category: hotspot.category, size: 20),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child:
                          CategoryBadge(category: hotspot.category, size: 44)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hotspot.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hotspot.subtitle.isNotEmpty
                        ? hotspot.subtitle
                        : tr('cat_${hotspot.category}').toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: PassimColors.brand),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}
