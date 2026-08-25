import 'package:flutter/material.dart';
import '../../i18n/i18n.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../theme/dyk_theme.dart';
import '../../widgets/dyk_page_route.dart';
import 'notifications_screen.dart';

/// Encourages the user to grant "Allow all the time" (background) location,
/// which is what lets DYK notify them about hotspots even when the app is in
/// their pocket or fully closed. On Android 11+ this can't be granted from the
/// first dialog, so we explain why and route to the system setting if needed.
class BackgroundLocationScreen extends StatefulWidget {
  final VoidCallback onFinished;
  const BackgroundLocationScreen({super.key, required this.onFinished});

  @override
  State<BackgroundLocationScreen> createState() =>
      _BackgroundLocationScreenState();
}

class _BackgroundLocationScreenState extends State<BackgroundLocationScreen>
    with WidgetsBindingObserver {
  bool _granted = false;
  bool _requesting = false;
  bool _askedOnce = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Re-check when returning from the system settings page.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final granted = await Permission.locationAlways.isGranted;
    if (mounted) setState(() => _granted = granted);
  }

  Future<void> _enable() async {
    setState(() => _requesting = true);
    final status = await Permission.locationAlways.request();
    if (mounted) {
      setState(() {
        _granted = status.isGranted;
        _requesting = false;
        _askedOnce = true;
      });
    }
    // On Android 11+ the request usually can't grant background directly; if
    // it's still not granted after asking, send the user to app settings.
    if (!status.isGranted && mounted && _askedOnce) {
      await openAppSettings();
    }
  }

  void _next() {
    Navigator.of(context).push(DykPageRoute(
      page: NotificationsScreen(onFinished: widget.onFinished),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_granted ? '✅' : '🧭',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 24),
              Text(_granted ? 'You\'re all set!' : tr('ob_never_miss'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Text(
                _granted
                    ? tr('ob_notif_sub')
                    : 'To get notified when you walk past a hotspot — even with your screen off or the app closed — set location access to "Allow all the time".',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (!_granted) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: DykColors.yellow.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    tr('ob_bg_hint') + '\n'
                    'Without it, DYK only works while the app is open.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 40),
              if (_granted)
                ElevatedButton(
                  onPressed: _next,
                  child: const Text('CONTINUE'),
                )
              else ...[
                ElevatedButton(
                  onPressed: _requesting ? null : _enable,
                  child: _requesting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(tr('ob_allow_all_time')),
                ),
                TextButton(
                  onPressed: _next,
                  child: Text(tr('maybe_later')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
