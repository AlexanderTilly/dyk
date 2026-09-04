import 'package:cached_network_image/cached_network_image.dart';
import '../../services/step_store.dart';
import '../../utils/money.dart';
import 'package:flutter/material.dart';

import '../../models/tour.dart';
import '../../services/audio_service.dart';
import '../../services/auth_service.dart';
import '../../services/dyk_repository.dart';
import '../../theme/dyk_theme.dart';
import '../tour_detail_screen.dart';
import '../../i18n/i18n.dart';

const _typeLabels = {
  'history_walk': 'History Walks',
  'food_drink': 'Food & Drink',
  'custom': 'More Tours',
};

class ToursTab extends StatefulWidget {
  final List<Tour> tours;
  final DykRepositoryBase repo;
  final AuthService authService;
  final AudioService audioService;
  final String? headerImage; // per-city hero; bundled Palma is the fallback
  final String? cityName;

  const ToursTab({
    super.key,
    required this.tours,
    required this.repo,
    required this.authService,
    required this.audioService,
    this.headerImage,
    this.cityName,
  });

  @override
  State<ToursTab> createState() => _ToursTabState();
}

class _ToursTabState extends State<ToursTab> {
  String _search = '';
  String _who = 'all'; // all | dyk | creators
  String? _mode; // null = all transport modes

  // Clean filter tab: icon over label, yellow underline when active.
  Widget _chip(String label, bool selected, VoidCallback onTap,
      {IconData? icon}) {
    final color = selected
        ? DykColors.yellow
        : Theme.of(context).brightness == Brightness.dark
            ? Colors.white70
            : Colors.black54;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon ?? Icons.grid_view_rounded, size: 22, color: color),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight:
                        selected ? FontWeight.w900 : FontWeight.w600,
                    color: color)),
            const SizedBox(height: 5),
            Container(
              height: 2.5,
              width: 28,
              decoration: BoxDecoration(
                color: selected ? DykColors.yellow : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.trim().toLowerCase();
    final tours = widget.tours.where((t) {
      if (_who == 'dyk' && t.isCreatorTour) return false;
      if (_who == 'creators' && !t.isCreatorTour) return false;
      if (_mode != null && t.transportMode != _mode) return false;
      if (q.isNotEmpty) {
        final hay =
            '${t.title} ${t.subtitle ?? ''} ${t.creatorName ?? ''} ${t.creatorHandle ?? ''}'
                .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
    final byType = <String, List<Tour>>{};
    for (final t in tours) {
      (byType[t.type] ??= []).add(t);
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        // City hero header: per-city image from admin, bundled Palma fallback.
        SizedBox(
          height: 210,
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.headerImage != null
                  ? CachedNetworkImage(
                      imageUrl: widget.headerImage!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Image.asset(
                          'assets/images/headers/palma.png',
                          fit: BoxFit.cover),
                    )
                  : Image.asset('assets/images/headers/palma.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: Colors.black26)),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Theme.of(context).scaffoldBackgroundColor,
                    ],
                    stops: const [0.35, 1.0],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        widget.cityName != null
                            ? '${tr('nav_tours')} · ${widget.cityName!.toUpperCase()}'
                            : tr('nav_tours'),
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5)),
                    const SizedBox(height: 2),
                    Text(tr('tours_sub'),
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            hintText: tr('search_tours'),
            prefixIcon: const Icon(Icons.search),
            isDense: true,
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          ),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [
            _chip(tr('all'), _who == 'all',
                () => setState(() => _who = 'all'),
                icon: Icons.grid_view_rounded),
            _chip('Originals', _who == 'dyk',
                () => setState(() => _who = 'dyk'),
                icon: Icons.star_outline),
            _chip('Creators', _who == 'creators',
                () => setState(() => _who = 'creators'),
                icon: Icons.groups_outlined),
            Container(
                width: 1,
                height: 34,
                color: Colors.white24,
                margin: const EdgeInsets.symmetric(horizontal: 4)),
            _chip(tr('mode_walking'), _mode == 'walking',
                () => setState(() => _mode = _mode == 'walking' ? null : 'walking'),
                icon: Icons.directions_walk),
            _chip(tr('mode_cycling'), _mode == 'cycling',
                () => setState(() => _mode = _mode == 'cycling' ? null : 'cycling'),
                icon: Icons.directions_bike),
            _chip(tr('mode_driving'), _mode == 'driving',
                () => setState(() => _mode = _mode == 'driving' ? null : 'driving'),
                icon: Icons.directions_car),
            _chip(tr('mode_boat'), _mode == 'boat',
                () => setState(() => _mode = _mode == 'boat' ? null : 'boat'),
                icon: Icons.sailing),
          ]),
        ),
        const SizedBox(height: 12),
        // Curated sections — only on the unfiltered view.
        if (q.isEmpty && _who == 'all' && _mode == null) ...[
          ..._trendingSection(),
          ..._picksSection(),
          ..._creatorsSection(),
        ],
        if (tours.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: Text(tr('tours_empty'))),
          )
        else
          for (final type in _typeLabels.keys)
            if (byType[type]?.isNotEmpty ?? false) ...[
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(_typeLabels[type]!,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              for (final t in byType[type]!)
                _TourCard(
                  tour: t,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => TourDetailScreen(
                      tour: t,
                      repo: widget.repo,
                      authService: widget.authService,
                      audioService: widget.audioService,
                    ),
                  )),
                ),
            ],
      ],
    );
  }
}

extension _ToursSections on _ToursTabState {
  void _openTour(Tour t) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TourDetailScreen(
        tour: t,
        repo: widget.repo,
        authService: widget.authService,
        audioService: widget.audioService,
      ),
    ));
  }

  Widget _sectionHeader(IconData icon, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        child: Row(children: [
          Icon(icon, color: DykColors.yellow, size: 20),
          const SizedBox(width: 8),
          Text(title.toUpperCase(),
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 0.5)),
        ]),
      );

  List<Widget> _trendingSection() {
    final trending = widget.tours.where((t) => t.isTrending).toList();
    if (trending.isEmpty) return const [];
    return [
      _sectionHeader(Icons.local_fire_department, tr('trending_now')),
      SizedBox(
        height: 200,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: trending.length,
          itemBuilder: (context, i) {
            final t = trending[i];
            return GestureDetector(
              onTap: () => _openTour(t),
              child: Container(
                width: 310,
                margin: const EdgeInsets.only(right: 12),
                clipBehavior: Clip.antiAlias,
                decoration:
                    BoxDecoration(borderRadius: BorderRadius.circular(18)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    t.heroImage != null
                        ? CachedNetworkImage(
                            imageUrl: t.heroImage!, fit: BoxFit.cover)
                        : Container(color: PassimColors.surface),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black87],
                          stops: [0.4, 1.0],
                        ),
                      ),
                    ),
                    if (t.isCreatorTour)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: DykColors.yellow,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text('with ${t.creatorName}',
                              style: const TextStyle(
                                  color: DykColors.black,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11)),
                        ),
                      ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 10,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.title.toUpperCase(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  height: 1.1)),
                          const SizedBox(height: 4),
                          Row(children: [
                            Icon(transportIcon(t.transportMode),
                                color: Colors.white70, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              [
                                if (t.distanceMeters != null)
                                  '${(t.distanceMeters! / 1000).toStringAsFixed(1)} km',
                                if (t.estMinutes != null)
                                  t.estMinutes! >= 90
                                      ? '~${(t.estMinutes! / 60).toStringAsFixed(1)} h'
                                      : '~${t.estMinutes} min',
                              ].join(' · '),
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 18),
    ];
  }

  List<Widget> _picksSection() {
    final picks = widget.tours.where((t) => t.isPick).toList();
    if (picks.isEmpty) return const [];
    return [
      _sectionHeader(Icons.star, tr('dyk_picks')),
      SizedBox(
        height: 210,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: picks.length,
          itemBuilder: (context, i) {
            final t = picks[i];
            return GestureDetector(
              onTap: () => _openTour(t),
              child: Container(
                width: 150,
                margin: const EdgeInsets.only(right: 12),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: PassimColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: t.heroImage != null
                          ? CachedNetworkImage(
                              imageUrl: t.heroImage!,
                              width: double.infinity,
                              fit: BoxFit.cover)
                          : Container(color: PassimColors.surface),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                  height: 1.15)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: t.isFree
                                  ? DykColors.green
                                  : DykColors.yellow,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                                t.isFree
                                    ? tr('free')
                                    : (t.isCreatorTour
                                        ? 'CREATOR'
                                        : euros(t.priceCents)),
                                style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    color: t.isFree
                                        ? Colors.white
                                        : DykColors.black)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 18),
    ];
  }

  List<Widget> _creatorsSection() {
    // Distinct creators, built from the tours themselves.
    final byCreator = <String, List<Tour>>{};
    for (final t in widget.tours) {
      if (t.isCreatorTour) (byCreator[t.creatorName!] ??= []).add(t);
    }
    if (byCreator.isEmpty) return const [];
    return [
      _sectionHeader(Icons.groups, tr('creators_love')),
      SizedBox(
        height: 108,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            for (final e in byCreator.entries)
              GestureDetector(
                onTap: () => setState(() {
                  _who = 'creators';
                  _search = e.key;
                }),
                child: Container(
                  width: 84,
                  margin: const EdgeInsets.only(right: 8),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: PassimColors.surface,
                        backgroundImage: e.value.first.creatorAvatar != null
                            ? CachedNetworkImageProvider(
                                e.value.first.creatorAvatar!)
                            : null,
                        child: e.value.first.creatorAvatar == null
                            ? const Icon(Icons.person,
                                color: Colors.white54)
                            : null,
                      ),
                      const SizedBox(height: 6),
                      Text(e.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 12)),
                      Text(
                          '${e.value.length} ${e.value.length == 1 ? tr('tour_one') : tr('nav_tours').toLowerCase()}',
                          style: const TextStyle(
                              fontSize: 10.5, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
    ];
  }
}

class _TourCard extends StatelessWidget {
  final Tour tour;
  final VoidCallback onTap;
  const _TourCard({required this.tour, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final meta = <String>[
      if (tour.distanceMeters != null)
        tour.transportMode == 'walking'
            ? '${StepStore.fmt(StepStore.stepsFromMeters(tour.distanceMeters!))} ${tr('steps_unit')}'
            : '${(tour.distanceMeters! / 1000).toStringAsFixed(1)} km',
      if (tour.estMinutes != null) '~${tour.estMinutes} min',
    ].join(' · ');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        decoration: BoxDecoration(
          color: dark ? PassimColors.surface : Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tour.heroImage != null)
              Stack(children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CachedNetworkImage(
                    imageUrl: tour.heroImage!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorWidget: (_, __, ___) =>
                        Container(color: Colors.black12),
                  ),
                ),
                if (tour.isCreatorTour)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: DykColors.yellow,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (tour.creatorAvatar != null) ...[
                          CircleAvatar(
                            radius: 9,
                            backgroundImage: CachedNetworkImageProvider(
                                tour.creatorAvatar!),
                          ),
                          const SizedBox(width: 5),
                        ] else ...[
                          const Icon(Icons.star,
                              size: 12, color: DykColors.black),
                          const SizedBox(width: 4),
                        ],
                        Text('with ${tour.creatorName}',
                            style: const TextStyle(
                                color: DykColors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 11)),
                      ]),
                    ),
                  ),
              ]),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tour.title.toUpperCase(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 17)),
                  if (tour.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(tour.subtitle!,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      tour.transportMode == 'walking'
                          ? FootstepsIcon(
                              size: 15,
                              color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color ??
                                  Colors.grey)
                          : Icon(transportIcon(tour.transportMode),
                              size: 15,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(meta,
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              tour.isFree ? DykColors.green : DykColors.yellow,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                            tour.isFree ? tr('free') : euros(tour.priceCents),
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: tour.isFree
                                    ? Colors.white
                                    : DykColors.black)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
