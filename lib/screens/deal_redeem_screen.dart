import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/hot_deal.dart';
import '../services/dyk_repository.dart';
import '../theme/dyk_theme.dart';
import '../i18n/i18n.dart';

/// Live redemption screen. The server issues a one-time code valid 15 min:
///  - 'scan' deals: staff scans the QR (or types the short code) in their
///    merchant portal — the server marks it used.
///  - 'show' deals: staff just looks at the screen; the moving countdown and
///    pulsing frame make a screenshot obviously fake.
class DealRedeemScreen extends StatefulWidget {
  final HotDeal deal;
  final DykRepositoryBase repo;

  const DealRedeemScreen({super.key, required this.deal, required this.repo});

  @override
  State<DealRedeemScreen> createState() => _DealRedeemScreenState();
}

class _DealRedeemScreenState extends State<DealRedeemScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _issue;
  String? _error;
  Duration _left = Duration.zero;
  Timer? _ticker;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _issue = null;
      _error = null;
    });
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString('anon_install_id');
    final res = await widget.repo.startRedeem(widget.deal.id, key);
    if (!mounted) return;
    if (res == null || res['error'] != null) {
      setState(() => _error = tr('redeem_failed'));
      return;
    }
    setState(() => _issue = res);
    final expires = DateTime.tryParse(res['expires_at'] as String? ?? '');
    _ticker?.cancel();
    void tick() {
      if (expires == null || !mounted) return;
      final left = expires.toUtc().difference(DateTime.now().toUtc());
      setState(() => _left = left.isNegative ? Duration.zero : left);
      if (left.isNegative) _ticker?.cancel();
    }

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    tick();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final code = _issue?['code'] as String?;
    final expired = _issue != null && _left == Duration.zero && _ticker != null && !_ticker!.isActive;
    final isScan = widget.deal.redeemMode == 'scan';

    return Scaffold(
      backgroundColor: DykColors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(widget.deal.businessName,
            style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _error != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!,
                        style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                        onPressed: _start, child: Text(tr('try_again'))),
                  ],
                )
              : code == null
                  ? const CircularProgressIndicator(color: DykColors.yellow)
                  : AnimatedBuilder(
                      animation: _pulse,
                      builder: (context, _) {
                        final glow = 4 + 10 * _pulse.value;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(widget.deal.offerText,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    height: 1.3)),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                    color: expired
                                        ? Colors.redAccent
                                        : DykColors.yellow,
                                    width: 5),
                                boxShadow: [
                                  BoxShadow(
                                    color: (expired
                                            ? Colors.redAccent
                                            : DykColors.yellow)
                                        .withValues(alpha: 0.55),
                                    blurRadius: glow * 2,
                                    spreadRadius: glow,
                                  ),
                                ],
                              ),
                              child: QrImageView(
                                data: 'DYK:$code',
                                size: 210,
                                padding: EdgeInsets.zero,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(code,
                                style: const TextStyle(
                                    color: DykColors.yellow,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 6)),
                            const SizedBox(height: 6),
                            expired
                                ? TextButton(
                                    onPressed: _start,
                                    child: Text(tr('get_new_code'),
                                        style: const TextStyle(
                                            color: Colors.redAccent,
                                            fontWeight: FontWeight.w800)),
                                  )
                                : Text(
                                    '${tr('valid_for')} ${_fmt(_left)}',
                                    style: const TextStyle(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16),
                                  ),
                            const SizedBox(height: 14),
                            Text(
                              isScan
                                  ? tr('redeem_hint_scan')
                                  : tr('redeem_hint_show'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 13),
                            ),
                          ],
                        );
                      },
                    ),
        ),
      ),
    );
  }
}
