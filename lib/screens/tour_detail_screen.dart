import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/step_store.dart';
import '../utils/money.dart';
import 'package:flutter/material.dart';

import '../models/tour.dart';
import '../models/tour_stop.dart';
import '../services/audio_service.dart';
import '../services/auth_service.dart';
import '../services/dyk_repository.dart';
import '../theme/dyk_theme.dart';
import 'active_tour_screen.dart';
import '../i18n/i18n.dart';

class TourDetailScreen extends StatefulWidget {
  final Tour tour;
  final DykRepositoryBase repo;
  final AuthService authService;
  final AudioService audioService;

  const TourDetailScreen({
    super.key,
    required this.tour,
    required this.repo,
    required this.authService,
    required this.audioService,
  });

  @override
  State<TourDetailScreen> createState() => _TourDetailScreenState();
}

class _TourDetailScreenState extends State<TourDetailScreen> {
  List<TourStop> _stops = [];
  bool _paused = false;
  bool _unlocked = false;
  bool _loading = true;
  // Stops the user chose to leave out (already seen it, too far away, …).
  final Set<String> _skipped = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _paused = prefs.getString('paused_tour_id') == widget.tour.id;
    final stops = await widget.repo.loadTourStops(widget.tour.id);
    final unlocked =
        widget.tour.isFree || await widget.repo.hasTour(widget.tour.id);
    if (!mounted) return;
    setState(() {
      _stops = stops;
      _unlocked = unlocked;
      _loading = false;
    });
  }

  Future<void> _unlock() async {
    if (!widget.authService.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('sign_in_unlock_tour'))),
      );
      return;
    }
    final err = await widget.repo.unlockTour(widget.tour.id);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    setState(() => _unlocked = true);
  }

  static const _mapboxToken =
      'pk.eyJ1IjoibGl0dGxld2h5IiwiYSI6ImNtZHJnMjc2bzBoM2EybHNmMWtpNW4xd24ifQ.NMHAZQhN_eP_3wxFUfNhdw';

  bool _starting = false;

  Future<void> _start() async {
    final included =
        _stops.where((s) => !_skipped.contains(s.id)).toList();
    if (included.isEmpty) return;
    var tour = widget.tour;
    // Skipped stops → the stored route no longer matches. Re-route through
    // the remaining stops only (loop back to the first on hop-on tours).
    if (_skipped.isNotEmpty &&
        included.where((s) => s.lat != null && s.lng != null).length >= 2 &&
        tour.transportMode != 'boat') {
      setState(() => _starting = true);
      tour = await _rerouted(tour, included) ?? tour;
      if (!mounted) return;
      setState(() => _starting = false);
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ActiveTourScreen(
        tour: tour,
        stops: included,
        repo: widget.repo,
        audioService: widget.audioService,
      ),
    ));
  }

  /// Fresh road route through [included] only. Returns null on any failure —
  /// the stored full route is a safe fallback.
  Future<Tour?> _rerouted(Tour t, List<TourStop> included) async {
    try {
      final pts = [
        for (final s in included)
          if (s.lat != null && s.lng != null) '${s.lng},${s.lat}',
      ];
      if (t.startMode == 'hop_on') pts.add(pts.first); // close the loop
      final profile = switch (t.transportMode) {
        'cycling' => 'cycling',
        'driving' => 'driving',
        _ => 'walking',
      };
      final url = Uri.parse(
          'https://api.mapbox.com/directions/v5/mapbox/$profile/'
          '${pts.join(';')}'
          '?geometries=geojson&overview=full&steps=true'
          // continue_straight forbids doubling back — right for cars, but on
          // foot it forces silly detours around the block at spur stops.
          '${profile == 'driving' ? '&continue_straight=true' : ''}'
          '&access_token=$_mapboxToken');
      final res = await http.get(url).timeout(const Duration(seconds: 10));
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final route = (json['routes'] as List?)?.firstOrNull;
      if (route == null) return null;
      final steps = <Map<String, dynamic>>[
        for (final leg in (route['legs'] as List? ?? []))
          for (final st in (leg['steps'] as List? ?? []))
            {
              'instruction': st['maneuver']?['instruction'],
              'type': st['maneuver']?['type'],
              'modifier': st['maneuver']?['modifier'],
              'location': st['maneuver']?['location'],
            },
      ];
      return Tour(
        id: t.id,
        citypackId: t.citypackId,
        type: t.type,
        title: t.title,
        subtitle: t.subtitle,
        description: t.description,
        heroImage: t.heroImage,
        priceCents: t.priceCents,
        isPublished: t.isPublished,
        distanceMeters: (route['distance'] as num?)?.round(),
        estMinutes: ((route['duration'] as num?) ?? 0) > 0
            ? ((route['duration'] as num) / 60).round()
            : t.estMinutes,
        routeGeojson: route['geometry'] as Map<String, dynamic>?,
        transportMode: t.transportMode,
        startMode: t.startMode,
        creatorName: t.creatorName,
        creatorHandle: t.creatorHandle,
        creatorAvatar: t.creatorAvatar,
        creatorIntro: t.creatorIntro,
        ctaText: t.ctaText,
        ctaUrl: t.ctaUrl,
        checklist: t.checklist,
        isTrending: t.isTrending,
        isPick: t.isPick,
        routeSteps: steps,
        sortOrder: t.sortOrder,
      );
    } catch (_) {
      return null;
    }
  }

  void _toggleSkip(TourStop s) {
    setState(() {
      if (_skipped.contains(s.id)) {
        _skipped.remove(s.id);
      } else {
        _skipped.add(s.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tour;
    return Scaffold(
      backgroundColor: PassimColors.ink,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            // Creator tours get a taller poster hero with the title laid
            // over the image; DYK tours keep the hotspot-style layout.
            expandedHeight: 320,
            pinned: true,
            backgroundColor: PassimColors.ink,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  t.heroImage != null
                      ? CachedNetworkImage(
                          imageUrl: t.heroImage!, fit: BoxFit.cover)
                      : Container(color: Colors.black26),
                  // Soft fade into the page background at the bottom.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.center,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, PassimColors.ink],
                      ),
                    ),
                  ),
                  Positioned(
                      left: 16,
                      right: 16,
                      bottom: 14,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                                '${_stops.length} ${tr('stops')}'
                                    .toUpperCase(),
                                style: const TextStyle(
                                    color: DykColors.yellow,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1)),
                          ),
                          const SizedBox(height: 8),
                          Text(t.title,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  height: 1.05,
                                  fontWeight: FontWeight.w900)),
                          if (t.subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(t.subtitle!,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 14)),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...[
                    // One stats row: (creator ·) distance · time · stops.
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 12),
                      decoration: BoxDecoration(
                        color: PassimColors.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          if (t.isCreatorTour)
                          Expanded(
                            child: GestureDetector(
                              onTap: t.creatorHandle != null
                                  ? () => launchUrl(
                                      Uri.parse(
                                          'https://instagram.com/${t.creatorHandle}'),
                                      mode: LaunchMode.externalApplication)
                                  : null,
                              child: _Stat(
                                avatar: t.creatorAvatar,
                                icon: Icons.person,
                                label: t.creatorName ?? '',
                                sub: t.creatorHandle != null
                                    ? '@${t.creatorHandle}'
                                    : null,
                              ),
                            ),
                          ),
                          if (t.isCreatorTour) _statDivider,
                          if (t.distanceMeters != null)
                            Expanded(
                              child: _Stat(
                                icon: transportIcon(t.transportMode),
                                footsteps: t.transportMode == 'walking',
                                label: t.transportMode == 'walking'
                                    ? '${StepStore.fmt(StepStore.stepsFromMeters(t.distanceMeters!))} ${tr('steps_unit')}'
                                    : '${(t.distanceMeters! / 1000).toStringAsFixed(1)} km',
                                sub: t.transportMode == 'walking'
                                    ? '${(t.distanceMeters! / 1000).toStringAsFixed(1)} km'
                                    : null,
                              ),
                            ),
                          if (t.estMinutes != null) ...[
                            _statDivider,
                            Expanded(
                              child: _Stat(
                                icon: Icons.schedule,
                                label: t.estMinutes! >= 90
                                    ? '~${(t.estMinutes! / 60).toStringAsFixed(1)} h'
                                    : '~${t.estMinutes} min',
                              ),
                            ),
                          ],
                          _statDivider,
                          Expanded(
                            child: _Stat(
                              icon: Icons.place_outlined,
                              label: '${_stops.length} ${tr('stops')}',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (t.creatorIntro != null) ...[
                    // Spotify-style quote: no frame, just voice.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (t.creatorAvatar != null) ...[
                          CircleAvatar(
                            radius: 20,
                            backgroundImage:
                                CachedNetworkImageProvider(t.creatorAvatar!),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('“${t.creatorIntro}”',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontStyle: FontStyle.italic,
                                      fontSize: 15,
                                      height: 1.5)),
                              const SizedBox(height: 6),
                              Text(
                                '${t.creatorName ?? ''}'
                                '${t.creatorHandle != null ? ' · @${t.creatorHandle}' : ''}',
                                style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (t.description != null) ...[
                    Text(tr('about_tour'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(t.description!,
                        style: const TextStyle(
                            color: Colors.white70, height: 1.5)),
                  ],
                  const SizedBox(height: 16),
                  if (t.isCreatorTour && !_loading && _stops.isNotEmpty) ...[
                    // Filmstrip of stops: big image cards with number badges.
                    SizedBox(
                      height: 190,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _stops.length,
                        itemBuilder: (context, i) {
                          final s = _stops[i];
                          return Container(
                            width: 140,
                            margin: const EdgeInsets.only(right: 12),
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: PassimColors.surface,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      s.image != null && s.image!.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: s.image!,
                                              fit: BoxFit.cover)
                                          : Container(
                                              color: PassimColors.surface,
                                              child: const Icon(
                                                  Icons.place_outlined,
                                                  color: Colors.white24)),
                                      Positioned(
                                        top: 8,
                                        left: 8,
                                        child: CircleAvatar(
                                          radius: 12,
                                          backgroundColor: DykColors.yellow,
                                          child: Text('${i + 1}',
                                              style: const TextStyle(
                                                  color: DykColors.black,
                                                  fontSize: 12,
                                                  fontWeight:
                                                      FontWeight.w900)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    s.title ?? 'Stop ${i + 1}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        height: 1.2,
                                        fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (t.checklist.isNotEmpty) ...[
                    Text(tr('what_to_bring'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final item in t.checklist)
                          _ChecklistChip(label: item),
                      ],
                    ),
                    const SizedBox(height: 18),
                  ],
                  Text(
                      _skipped.isEmpty
                          ? '${_stops.length} ${tr('stops')}'
                          : '${_stops.length - _skipped.length} ${tr('of')} ${_stops.length} ${tr('stops')}',
                      style: const TextStyle(
                          color: DykColors.yellow,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(
                      tr('skip_hint'),
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 12)),
                  const SizedBox(height: 8),
                  if (_loading)
                    const Center(
                        child: Padding(
                      padding: EdgeInsets.all(24),
                      child:
                          CircularProgressIndicator(color: DykColors.yellow),
                    ))
                  else ...[
                    for (var i = 0; i < _stops.length; i++)
                      _StopRow(
                        // Number by position among included stops only.
                        index: _stops
                                .take(i)
                                .where((s) => !_skipped.contains(s.id))
                                .length +
                            1,
                        stop: _stops[i],
                        skipped: _skipped.contains(_stops[i].id),
                        onToggleSkip: () => _toggleSkip(_stops[i]),
                      ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
            height: 56,
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: DykColors.yellow,
                foregroundColor: DykColors.black,
              ),
              onPressed: _loading || _starting
                  ? null
                  : (_unlocked ? _start : _unlock),
              child: Text(
                _unlocked
                    ? (_paused
                        ? tr('resume_tour')
                        : _skipped.isEmpty
                            ? tr('start_tour')
                            : '${tr('start_tour')} · ${_stops.length - _skipped.length} ${tr('stops')}')
                    : (t.isFree
                        ? tr('start_tour')
                        : '${tr('unlock')} · ${euros(t.priceCents)}'),
                style: const TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }
}

const _statDivider = SizedBox(
  height: 34,
  child: VerticalDivider(color: Colors.white12, width: 16),
);

/// One cell in the stats row: icon (or avatar) over a short label.
class _Stat extends StatelessWidget {
  final String? avatar;
  final IconData icon;
  final String label;
  final String? sub;
  final bool footsteps;
  const _Stat(
      {this.avatar,
      required this.icon,
      required this.label,
      this.sub,
      this.footsteps = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (avatar != null)
          CircleAvatar(
              radius: 13, backgroundImage: CachedNetworkImageProvider(avatar!))
        else if (footsteps)
          const FootstepsIcon(size: 22)
        else
          Icon(icon, color: DykColors.yellow, size: 22),
        const SizedBox(height: 5),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800)),
        if (sub != null)
          Text(sub!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }
}

// Tappable checklist chip — check-off is local (resets when you leave).
class _ChecklistChip extends StatefulWidget {
  final String label;
  const _ChecklistChip({required this.label});

  @override
  State<_ChecklistChip> createState() => _ChecklistChipState();
}

class _ChecklistChipState extends State<_ChecklistChip> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _done = !_done),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _done
              ? DykColors.yellow.withValues(alpha: 0.18)
              : PassimColors.surface,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
              color: _done ? DykColors.yellow : Colors.white12, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _done ? Icons.check : checklistIcon(widget.label),
              color: _done ? DykColors.yellow : Colors.white70,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              widget.label,
              style: TextStyle(
                color: _done ? DykColors.yellow : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  final int index;
  final TourStop stop;
  final bool skipped;
  final VoidCallback onToggleSkip;

  const _StopRow({
    required this.index,
    required this.stop,
    required this.skipped,
    required this.onToggleSkip,
  });

  @override
  Widget build(BuildContext context) {
    final label = stop.title ?? 'Stop $index';
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: skipped ? 0.4 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Thumbnail with the stop number in the corner.
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: stop.image != null && stop.image!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: stop.image!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 56,
                          height: 56,
                          color: PassimColors.surface,
                          child: const Icon(Icons.place,
                              color: Colors.white38, size: 26),
                        ),
                ),
                Positioned(
                  top: -5,
                  left: -5,
                  child: CircleAvatar(
                    radius: 11,
                    backgroundColor:
                        skipped ? Colors.white24 : DykColors.yellow,
                    child: skipped
                        ? const Icon(Icons.remove,
                            size: 13, color: Colors.white70)
                        : Text('$index',
                            style: const TextStyle(
                                color: DykColors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          decoration: skipped
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          decorationColor: Colors.white54)),
                  if (skipped)
                    Text(tr('skipped_hint'),
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12))
                  else if (stop.blurb != null)
                    Text(stop.blurb!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 13)),
                ],
              ),
            ),
            IconButton(
              onPressed: onToggleSkip,
              tooltip: skipped ? tr('add_back') : tr('skip_stop'),
              icon: Icon(
                skipped
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: skipped ? Colors.white38 : DykColors.yellow,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
