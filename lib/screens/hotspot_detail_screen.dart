import 'package:flutter/material.dart';
import '../i18n/i18n.dart';
import 'navigate_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import '../models/hotspot.dart';
import '../services/audio_service.dart';
import '../services/auth_service.dart';
import '../services/dyk_repository.dart';
import '../services/entitlements.dart';
import '../services/saved_store.dart';
import '../theme/dyk_theme.dart';
import '../widgets/category_badge.dart';
import '../widgets/unlock_buttons.dart';

// Renders an image from a bundled asset or a remote URL.
Widget _dykImage(String src, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
  Widget fallback(_, __, ___) => Container(
        width: width,
        height: height,
        color: const Color(0xFF2A2A2A),
        child: const Icon(Icons.image_not_supported_outlined,
            color: Colors.white24, size: 32),
      );
  if (src.startsWith('http')) {
    return Image.network(src, width: width, height: height, fit: fit, errorBuilder: fallback);
  }
  return Image.asset(src, width: width, height: height, fit: fit, errorBuilder: fallback);
}

class HotspotDetailScreen extends StatefulWidget {
  final Hotspot hotspot;
  final AudioService audioService;
  final SavedStore? savedStore;
  final bool autoPlay;
  // Entitlement gating (optional — when absent, content is shown unlocked).
  final Entitlements? entitlements;
  final String? citypackId;
  final String? cityName;
  final int cityPriceCents;
  final DykRepositoryBase? repo;
  final AuthService? authService;
  final VoidCallback? onContinueTour;

  const HotspotDetailScreen({
    super.key,
    required this.hotspot,
    required this.audioService,
    this.savedStore,
    this.autoPlay = false,
    this.entitlements,
    this.citypackId,
    this.cityName,
    this.cityPriceCents = 0,
    this.repo,
    this.authService,
    this.onContinueTour,
  });

  @override
  State<HotspotDetailScreen> createState() => _HotspotDetailScreenState();
}

class _HotspotDetailScreenState extends State<HotspotDetailScreen> {
  bool _saved = false;
  bool _storyExpanded = false;
  int _imageIndex = 0;
  final PageController _imagePage = PageController();

  // Full content is available for free hotspots, or once the city is unlocked
  // (or premium). Without an entitlements context, treat as unlocked.
  bool get _unlocked {
    final e = widget.entitlements;
    if (e == null) return true;
    return widget.hotspot.isFree || e.isCityUnlocked(widget.citypackId);
  }

  @override
  void initState() {
    super.initState();
    _saved = widget.savedStore?.isSaved(widget.hotspot.id) ?? false;
    if (_unlocked &&
        widget.autoPlay &&
        widget.hotspot.audioFile.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) =>
          widget.audioService.play(widget.hotspot.audioFile,
              title: widget.hotspot.name,
              hotspotId: widget.hotspot.id,
              artUrl: widget.hotspot.images.isNotEmpty
                  ? widget.hotspot.images.first
                  : null));
    }
  }

  @override
  void dispose() {
    _imagePage.dispose();
    super.dispose();
  }

  // Locked teaser shown when the city isn't unlocked and the hotspot isn't free.
  Widget _buildLocked(BuildContext context, Hotspot h) {
    final city = widget.cityName ?? 'this city';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (h.subtitle.isNotEmpty) ...[
            Text(h.subtitle,
                style: TextStyle(
                    color: Colors.amber.shade300,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
          ],
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF232323),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: DykColors.yellow.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                const Icon(Icons.lock_outline,
                    color: DykColors.yellow, size: 36),
                const SizedBox(height: 12),
                Text(tr('unlock_city_story').replaceFirst('{city}', city),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text(
                  'Full narration, the story and all Did You Know? facts.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 20),
                if (widget.entitlements != null &&
                    widget.repo != null &&
                    widget.authService != null &&
                    widget.citypackId != null)
                  UnlockButtons(
                    cityName: city,
                    priceCents: widget.cityPriceCents,
                    cityId: widget.citypackId!,
                    entitlements: widget.entitlements!,
                    repo: widget.repo!,
                    authService: widget.authService!,
                    onUnlocked: () => setState(() {}),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openImageViewer(int initialIndex) {
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _ImageViewer(
        images: widget.hotspot.images,
        captions: widget.hotspot.imageCaptions,
        initialIndex: initialIndex,
      ),
    ));
  }

  // Only admin-authored facts (description is shown in its own section).
  List<String> get _facts => widget.hotspot.facts;

  @override
  Widget build(BuildContext context) {
    final h = widget.hotspot;
    return Scaffold(
      backgroundColor: DykColors.black,
      bottomNavigationBar: widget.onContinueTour == null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 54,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DykColors.yellow,
                      side: BorderSide(
                          color: DykColors.yellow, width: 1.5),
                    ),
                    icon: const Icon(Icons.navigation_outlined, size: 20),
                    label: Text(tr('navigate_there'),
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 15)),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            NavigateScreen(hotspot: widget.hotspot),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: DykColors.yellow,
                        foregroundColor: DykColors.black),
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(tr('continue_tour'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 16)),
                    onPressed: widget.onContinueTour,
                  ),
                ),
              ),
            ),
      body: CustomScrollView(
        slivers: [
          // ---- Immersive hero ----
          SliverAppBar(
            expandedHeight: 380,
            pinned: true,
            backgroundColor: DykColors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: Icon(_saved ? Icons.favorite : Icons.favorite_border,
                    color: DykColors.yellow),
                onPressed: () async {
                  await widget.savedStore?.toggle(widget.hotspot.id);
                  setState(() => _saved = !_saved);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(_saved ? 'Saved' : 'Removed from saved'),
                      duration: const Duration(seconds: 1),
                    ));
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.ios_share, color: Colors.white),
                onPressed: () {},
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Swipeable image carousel — all photos live in the header.
                  if (h.images.isNotEmpty)
                    PageView.builder(
                      controller: _imagePage,
                      itemCount: h.images.length,
                      onPageChanged: (i) => setState(() => _imageIndex = i),
                      itemBuilder: (_, i) => GestureDetector(
                        onTap: () => _openImageViewer(i),
                        child: _dykImage(h.images[i]),
                      ),
                    )
                  else
                    Container(color: const Color(0xFF2A2A2A)),
                  // Page dots (only when there's more than one image).
                  if (h.images.length > 1)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 10,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < h.images.length; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              width: i == _imageIndex ? 20 : 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: i == _imageIndex
                                    ? DykColors.yellow
                                    : Colors.white60,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                        ],
                      ),
                    ),
                  // dark gradient for legibility
                  const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black54,
                            DykColors.black,
                          ],
                          stops: [0.3, 0.7, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // category badge + title overlay
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 18,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CategoryBadge(category: h.category, size: 44),
                            const Spacer(),
                            if (h.year.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: DykColors.yellow,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text('EST. ${h.year}',
                                    style: const TextStyle(
                                      color: DykColors.black,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    )),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          h.name.toUpperCase(),
                          style: GoogleFonts.bebasNeue(
                            color: Colors.white,
                            fontSize: 38,
                            height: 1.0,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (h.subtitle.isNotEmpty)
                          Text(h.subtitle,
                              style: TextStyle(
                                color: Colors.amber.shade300,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (!_unlocked)
            SliverToBoxAdapter(child: _buildLocked(context, h)),
          if (_unlocked)
          SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 16),

              // ---- Branded audio player ----
              if (h.audioFile.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _BrandedAudioPlayer(
                    audioService: widget.audioService,
                    source: h.audioFile,
                    title: h.name,
                    artUrl: h.images.isNotEmpty ? h.images.first : null,
                    hotspotId: h.id,
                  ),
                ),

              // ---- Description / story ----
              if (h.description.trim().isNotEmpty) ...[
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('THE STORY',
                          style: GoogleFonts.bebasNeue(
                            color: Colors.white,
                            fontSize: 22,
                            letterSpacing: 1,
                          )),
                      const SizedBox(height: 8),
                      Text(
                        h.description,
                        maxLines: _storyExpanded ? null : 4,
                        overflow: _storyExpanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14.5,
                          height: 1.6,
                        ),
                      ),
                      if (h.description.length > 180)
                        GestureDetector(
                          onTap: () => setState(
                              () => _storyExpanded = !_storyExpanded),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _storyExpanded ? 'Read less' : 'Read more',
                              style: const TextStyle(
                                color: DykColors.yellow,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              // ---- Did You Know? cards ----
              if (_facts.isNotEmpty) ...[
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('DID YOU KNOW?',
                      style: GoogleFonts.bebasNeue(
                        color: DykColors.yellow,
                        fontSize: 22,
                        letterSpacing: 1,
                      )),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 150,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _facts.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => _FactCard(text: _facts[i], index: i + 1),
                  ),
                ),
              ],

              // ---- Video ----
              if (h.videos.isNotEmpty) ...[
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('WATCH',
                      style: GoogleFonts.bebasNeue(
                        color: Colors.white,
                        fontSize: 22,
                        letterSpacing: 1,
                      )),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _VideoPlayer(url: h.videos.first),
                ),
              ],

              // ---- AR teaser ----
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _ARButton(),
              ),

              SizedBox(height: 40 + MediaQuery.of(context).padding.bottom),
            ]),
          ),
        ],
      ),
    );
  }
}

class _FactCard extends StatelessWidget {
  final String text;
  final int index;
  const _FactCard({required this.text, required this.index});

  void _openFull(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Text('💡 FACT $index',
                  style: const TextStyle(
                    color: DykColors.yellow,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  )),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  child: Text(text,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.55)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openFull(context),
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF232323),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DykColors.yellow.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('💡 FACT',
                    style: TextStyle(
                      color: DykColors.yellow,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    )),
                Text(' $index',
                    style: TextStyle(
                      color: DykColors.yellow,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    )),
                const Spacer(),
                const Icon(Icons.open_in_full,
                    color: Colors.white38, size: 14),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(text,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13.5, height: 1.45)),
            ),
            const SizedBox(height: 6),
            Text(tr('tap_to_read'),
                style: TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _ARButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DykColors.yellow),
      ),
      child: Row(
        children: [
          const Icon(Icons.view_in_ar, color: DykColors.yellow, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('view_ar'),
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
                Text(tr('view_ar_sub'),
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: DykColors.yellow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('SOON',
                style: TextStyle(
                    color: DykColors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _VideoPlayer extends StatefulWidget {
  final String url;
  const _VideoPlayer({required this.url});

  @override
  State<_VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<_VideoPlayer> {
  VideoPlayerController? _controller;
  bool _ready = false;
  double _speed = 1.0;
  static const _speeds = [1.0, 1.25, 1.5, 0.75];

  void _cycleSpeed() {
    final next = _speeds[(_speeds.indexOf(_speed) + 1) % _speeds.length];
    setState(() => _speed = next);
    _controller?.setPlaybackSpeed(next);
  }

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() => _ready = true);
      }).catchError((_) {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (!_ready || c == null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFF232323),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
            child: CircularProgressIndicator(color: DykColors.yellow)),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(c),
            GestureDetector(
              onTap: () => setState(
                  () => c.value.isPlaying ? c.pause() : c.play()),
              child: Container(
                color: Colors.transparent,
                child: c.value.isPlaying
                    ? const SizedBox.expand()
                    : Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: DykColors.yellow,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow,
                            color: DykColors.black, size: 32),
                      ),
              ),
            ),
            // Playback speed pill (tap to cycle).
            Positioned(
              bottom: 8,
              right: 8,
              child: GestureDetector(
                onTap: _cycleSpeed,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _speed == 1.0
                        ? Colors.black54
                        : DykColors.yellow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _speed == _speed.roundToDouble()
                        ? '${_speed.toInt()}x'
                        : '${_speed}x',
                    style: TextStyle(
                      color: _speed == 1.0
                          ? Colors.white
                          : DykColors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandedAudioPlayer extends StatefulWidget {
  final AudioService audioService;
  final String source;
  final String? title;
  final String? artUrl;
  final String? hotspotId;
  const _BrandedAudioPlayer({
    required this.audioService,
    required this.source,
    this.title,
    this.artUrl,
    this.hotspotId,
  });

  @override
  State<_BrandedAudioPlayer> createState() => _BrandedAudioPlayerState();
}

class _BrandedAudioPlayerState extends State<_BrandedAudioPlayer> {
  bool _playing = false;
  bool _started = false; // this source has been loaded at least once
  double _speed = 1.0;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;

  static const _speeds = [1.0, 1.25, 1.5, 0.75];

  @override
  void initState() {
    super.initState();
    // If this hotspot's narration is already loaded (mini player), resume
    // instead of restarting when play is tapped.
    _started =
        widget.audioService.nowPlaying.value?.source == widget.source;
    widget.audioService.positionStream.listen((p) {
      if (mounted) setState(() => _pos = p);
    });
    widget.audioService.durationStream.listen((d) {
      if (mounted && d != null) setState(() => _dur = d);
    });
    widget.audioService.playerStateStream.listen((s) {
      if (mounted) setState(() => _playing = s.playing);
    });
    widget.audioService.speedStream.listen((s) {
      if (mounted) setState(() => _speed = s);
    });
  }

  Future<void> _togglePlay() async {
    if (_playing) {
      await widget.audioService.pause();
    } else if (_started) {
      // Resume where we left off instead of restarting the story.
      await widget.audioService.resume();
    } else {
      _started = true;
      await widget.audioService.play(
        widget.source,
        title: widget.title,
        artUrl: widget.artUrl,
        hotspotId: widget.hotspotId,
      );
    }
  }

  void _cycleSpeed() {
    final next =
        _speeds[(_speeds.indexOf(_speed) + 1) % _speeds.length];
    widget.audioService.setSpeed(next);
  }

  String get _speedLabel =>
      _speed == _speed.roundToDouble()
          ? '${_speed.toInt()}x'
          : '${_speed}x';

  String _fmt(Duration d) =>
      '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final progress = _dur.inMilliseconds > 0
        ? _pos.inMilliseconds / _dur.inMilliseconds
        : 0.0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF232323),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: '-10 s',
            icon: const Icon(Icons.replay_10,
                color: Colors.white70, size: 26),
            onPressed: () =>
                widget.audioService.skip(const Duration(seconds: -10)),
          ),
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: DykColors.yellow,
                shape: BoxShape.circle,
              ),
              child: Icon(_playing ? Icons.pause : Icons.play_arrow,
                  color: DykColors.black, size: 30),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: '+10 s',
            icon: const Icon(Icons.forward_10,
                color: Colors.white70, size: 26),
            onPressed: () =>
                widget.audioService.skip(const Duration(seconds: 10)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('LISTEN TO THE STORY',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        )),
                    // Playback speed — tap to cycle 1x → 1.25x → 1.5x → 0.75x.
                    GestureDetector(
                      onTap: _cycleSpeed,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: _speed == 1.0
                              ? Colors.white12
                              : DykColors.yellow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(_speedLabel,
                            style: TextStyle(
                              color: _speed == 1.0
                                  ? Colors.white70
                                  : DykColors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            )),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: DykColors.yellow,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: DykColors.yellow,
                  ),
                  child: Slider(
                    value: progress.clamp(0.0, 1.0),
                    onChanged: (v) => widget.audioService
                        .seekTo(Duration(milliseconds: (v * _dur.inMilliseconds).toInt())),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(_pos),
                        style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    Text(_fmt(_dur),
                        style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Fullscreen, swipeable, zoomable image viewer with an optional caption
// describing what the image shows.
class _ImageViewer extends StatefulWidget {
  final List<String> images;
  final List<String?> captions;
  final int initialIndex;

  const _ImageViewer({
    required this.images,
    required this.captions,
    required this.initialIndex,
  });

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _captionFor(int i) =>
      (i >= 0 && i < widget.captions.length) ? widget.captions[i] : null;

  @override
  Widget build(BuildContext context) {
    final caption = _captionFor(_index);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _index = i),
            // Every image gets the same full-width 4:3 frame (cover-cropped)
            // so swiping through the gallery looks uniform regardless of
            // each photo's own proportions. Pinch to zoom still works.
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: ClipRect(
                    child: _dykImage(widget.images[i], fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
          ),
          // Close button.
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          // Page counter.
          if (widget.images.length > 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 14,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text('${_index + 1} / ${widget.images.length}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          // Caption.
          if (caption != null && caption.trim().isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                    20, 16, 20, 20 + MediaQuery.of(context).padding.bottom),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: Text(
                  caption,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15, height: 1.4),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
