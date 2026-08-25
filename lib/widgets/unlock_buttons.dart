import 'package:flutter/material.dart';
import '../utils/money.dart';

import '../services/auth_service.dart';
import '../services/dyk_repository.dart';
import '../services/entitlements.dart';
import '../theme/dyk_theme.dart';
import '../screens/auth_screen.dart';
import '../i18n/i18n.dart';

/// The two monetisation CTAs: unlock this city, or go premium (all cities).
/// Handles the sign-in requirement and the (currently free) unlock calls.
class UnlockButtons extends StatefulWidget {
  final String cityName;
  final int priceCents;
  final String cityId;
  final Entitlements entitlements;
  final DykRepositoryBase repo;
  final AuthService authService;
  final VoidCallback onUnlocked;

  const UnlockButtons({
    super.key,
    required this.cityName,
    required this.priceCents,
    required this.cityId,
    required this.entitlements,
    required this.repo,
    required this.authService,
    required this.onUnlocked,
  });

  @override
  State<UnlockButtons> createState() => _UnlockButtonsState();
}

class _UnlockButtonsState extends State<UnlockButtons> {
  bool _busy = false;

  Future<bool> _ensureSignedIn() async {
    if (widget.authService.isSignedIn) return true;
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => AuthScreen(authService: widget.authService),
    ));
    return widget.authService.isSignedIn || ok == true;
  }

  Future<void> _run(Future<String?> Function() action, String successMsg) async {
    setState(() => _busy = true);
    if (!await _ensureSignedIn()) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    final err = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null && err != 'signin') {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(successMsg)));
    widget.onUnlocked();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: DykColors.yellow,
              foregroundColor: DykColors.black,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            onPressed: _busy
                ? null
                : () => _run(
                      () => widget.entitlements.unlockCity(
                          widget.repo, widget.authService, widget.cityId),
                      'Unlocked ${widget.cityName}! Enjoy 🎧',
                    ),
            child: Text(
              widget.priceCents > 0
                  ? '${tr('unlock_city')} ${widget.cityName} · ${euros(widget.priceCents)}'
                  : '${tr('unlock_city')} ${widget.cityName}',
              style: const TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 15),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: DykColors.yellow,
              side: const BorderSide(color: DykColors.yellow, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            onPressed: _busy
                ? null
                : () => _run(
                      () => widget.entitlements
                          .goPremium(widget.repo, widget.authService),
                      'Premium activated — all cities unlocked! 👑',
                    ),
            child: Text(tr('go_premium_all'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ),
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: DykColors.yellow)),
          ),
      ],
    );
  }
}
