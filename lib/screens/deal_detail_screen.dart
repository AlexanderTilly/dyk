import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/hot_deal.dart';
import '../services/dyk_repository.dart';
import '../theme/dyk_theme.dart';
import '../i18n/i18n.dart';
import 'deal_redeem_screen.dart';

/// Full-page deal card — hotspot-parity content (hero image, about text,
/// gallery) plus the offer and the live Redeem button.
class DealDetailScreen extends StatelessWidget {
  final HotDeal deal;
  final DykRepositoryBase repo;

  const DealDetailScreen({super.key, required this.deal, required this.repo});

  @override
  Widget build(BuildContext context) {
    final hero = deal.headerImage ??
        (deal.images.isNotEmpty ? deal.images.first : null);
    final gallery =
        deal.images.where((i) => i != hero).toList(growable: false);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: hero != null ? 260 : 120,
            pinned: true,
            backgroundColor: DykColors.black,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.only(left: 16, right: 16, bottom: 14),
              title: Text(deal.businessName,
                  maxLines: 2,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(blurRadius: 8, color: Colors.black)])),
              background: hero != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(imageUrl: hero, fit: BoxFit.cover),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black87],
                              stops: [0.45, 1],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(color: DykColors.black),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The offer itself — the star of the page.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: DykColors.yellow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: DykColors.black, width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('todays_offer').toUpperCase(),
                            style: const TextStyle(
                                color: DykColors.black,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4)),
                        const SizedBox(height: 6),
                        Text(deal.offerText,
                            style: const TextStyle(
                                color: DykColors.black,
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                height: 1.25)),
                      ],
                    ),
                  ),
                  if ((deal.description ?? '').isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(tr('about_venue'),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text(deal.description!,
                        style: const TextStyle(fontSize: 14.5, height: 1.5)),
                  ],
                  if (gallery.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: gallery.length,
                        separatorBuilder: (_, i) => const SizedBox(width: 10),
                        itemBuilder: (_, i) => ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: gallery[i],
                            width: 160,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SizedBox(
          height: 56,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: DykColors.yellow,
              foregroundColor: DykColors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.local_fire_department, size: 26),
            label: Text(tr('redeem_now'),
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w900)),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => DealRedeemScreen(deal: deal, repo: repo),
            )),
          ),
        ),
      ),
    );
  }
}
