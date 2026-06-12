import 'package:flutter/material.dart';

import '../../models/city_pack.dart';
import '../../theme/dyk_theme.dart';

class CityPacksTab extends StatelessWidget {
  final List<CityPack> packs;
  final String activePackId;
  final void Function(CityPack) onDownload;

  const CityPacksTab({
    super.key,
    required this.packs,
    required this.activePackId,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('CITY PACKS',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text('Download city packs to unlock stories, deals and hidden gems.',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        if (packs.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No city packs available — check your connection.')),
          )
        else
          for (final p in packs)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: dark ? Colors.white10 : Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(p.name.toUpperCase(),
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 17)),
                      ),
                      if (p.id == activePackId)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: DykColors.green,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Text('DOWNLOADED',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('📍 ${p.city}, ${p.country}',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 6),
                  Text(p.description,
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: p.id == activePackId
                          ? null
                          : () => onDownload(p),
                      child: Text(
                          p.id == activePackId ? 'ACTIVE' : 'DOWNLOAD'),
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
