import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/internal_ad.dart';
import '../../services/auth_service.dart';
import '../../services/dyk_repository.dart';
import '../../services/entitlements.dart';
import '../../theme/dyk_theme.dart';
import '../../widgets/internal_ad_banner.dart';
import '../../widgets/pickpocket_banner.dart';
import '../pickpocket_map_screen.dart';
import '../premium_screen.dart';
import '../../i18n/i18n.dart';

/// A hub for everything that isn't a core tab: featured promos (Tapas Route),
/// pickpocket safety, premium and city tips.
class MoreTab extends StatefulWidget {
  final List<InternalAd> ads;
  final DykRepositoryBase repo;
  final AuthService authService;
  final Entitlements? entitlements;
  final String? citypackId;
  final String? cityName;
  final int cityPriceCents;

  const MoreTab({
    super.key,
    this.ads = const [],
    required this.repo,
    required this.authService,
    this.entitlements,
    this.citypackId,
    this.cityName,
    this.cityPriceCents = 0,
  });

  @override
  State<MoreTab> createState() => _MoreTabState();
}

class _MoreTabState extends State<MoreTab> {
  static const _ppBlue = Color(0xFF1559D6);
  List<InternalAd> _nearbyAds = [];

  @override
  void initState() {
    super.initState();
    _filterAds();
  }

  // Show only internal ads whose target is within radius of the user.
  Future<void> _filterAds() async {
    if (widget.ads.isEmpty) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low);
      final near = widget.ads.where((ad) {
        final meters = Geolocator.distanceBetween(
            pos.latitude, pos.longitude, ad.targetLat, ad.targetLng);
        return meters <= ad.radiusKm * 1000;
      }).toList();
      if (mounted) setState(() => _nearbyAds = near);
    } catch (_) {
      // No location → just show all ads rather than nothing.
      if (mounted) setState(() => _nearbyAds = widget.ads);
    }
  }

  void _openPremium() {
    final e = widget.entitlements;
    final cityId = widget.citypackId;
    if (e == null || cityId == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PremiumScreen(
        entitlements: e,
        repo: widget.repo,
        authService: widget.authService,
        cityId: cityId,
        cityName: widget.cityName ?? 'this city',
        cityPriceCents: widget.cityPriceCents,
      ),
    ));
  }

  void _comingSoon(String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(tr('coming_soon')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(t,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
      );

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Text(tr('more_title'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(tr('more_sub'),
            style: Theme.of(context).textTheme.bodyMedium),

        // Featured / GPS-targeted promos (Tapas Route etc.)
        if (_nearbyAds.isNotEmpty) ...[
          _sectionTitle(tr('featured')),
          for (final ad in _nearbyAds) ...[
            InternalAdBanner(ad: ad),
            const SizedBox(height: 12),
          ],
        ],

        // Safety
        _sectionTitle(tr('safety')),
        PickpocketBanner(onTap: _openPickpocketChooser),

        // Premium
        _sectionTitle(tr('premium')),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: DykColors.yellow.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Text('👑', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('go_premium'),
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text(tr('premium_pitch'),
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _openPremium,
                child: Text(tr('view_plans')),
              ),
            ],
          ),
        ),

        // City tips
        _sectionTitle(tr('city_tips')),
        GestureDetector(
          onTap: () => _comingSoon('City tips'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: dark ? PassimColors.surface : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Text('💡', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('local_tips'),
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(tr('local_tips_sub'),
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ---- Pickpocket flow (moved here from Explore) ----
  void _openPickpocketChooser() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/badges/pickpocket.png',
                  height: 56, width: 56),
              const SizedBox(height: 12),
              Text(tr('pickpocket_activity'),
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: PassimColors.ink)),
              const SizedBox(height: 4),
              Text(tr('pickpocket_help'),
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _ppBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.report_gmailerrorred),
                  label: Text(tr('report_activity'),
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                  onPressed: () {
                    Navigator.of(sheetCtx).pop();
                    _startReportFlow();
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _ppBlue,
                    side: const BorderSide(color: _ppBlue, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.map_outlined),
                  label: Text(tr('see_all'),
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                  onPressed: () {
                    Navigator.of(sheetCtx).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => PickpocketMapScreen(repo: widget.repo),
                    ));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startReportFlow() async {
    if (!widget.authService.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(tr('sign_in_report'))),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('report_pickpocket_q')),
        content: Text(
            'Do you want to report pickpocket activity at your current location? '
            'We\'ll show a temporary pin on the map for 3 hours.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(tr('no'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _ppBlue, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('yes')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final controller = TextEditingController();
    final description = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('describe_situation')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          maxLength: 280,
          decoration: InputDecoration(
            hintText:
                'What happened? Describe the pickpocket(s) — appearance, method...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(tr('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _ppBlue, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(tr('submit')),
          ),
        ],
      ),
    );
    if (description == null) return;
    await _submitReport(description);
  }

  Future<void> _submitReport(String description) async {
    Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('no_location'))),
        );
      }
      return;
    }
    final error = await widget.repo.reportPickpocket(
      lat: pos.latitude,
      lng: pos.longitude,
      description: description.isEmpty ? null : description,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ??
            'Thanks! Your report is now live on the map for 3 hours.'),
      ),
    );
  }
}
