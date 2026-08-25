import 'package:flutter/material.dart';
import '../../i18n/i18n.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../widgets/dyk_page_route.dart';
import 'background_location_screen.dart';
import 'notifications_screen.dart';

class LocationScreen extends StatefulWidget {
  final VoidCallback onFinished;
  const LocationScreen({super.key, required this.onFinished});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  bool _requesting = false;

  // Skip straight to notifications (used when location is declined).
  void _skip() {
    Navigator.of(context).push(DykPageRoute(
      page: NotificationsScreen(onFinished: widget.onFinished),
    ));
  }

  Future<void> _request() async {
    setState(() => _requesting = true);
    // Android 11+ requires a two-step flow: foreground ("while in use") here,
    // then background ("allow all the time") on the next screen. Requesting
    // background directly silently fails, so we grant foreground first.
    final foreground = await Permission.location.request();
    setState(() => _requesting = false);
    if (!mounted) return;
    if (foreground.isGranted) {
      // Move on to the dedicated "Allow all the time" step.
      Navigator.of(context).push(DykPageRoute(
        page: BackgroundLocationScreen(onFinished: widget.onFinished),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            tr('ob_location_later')),
      ));
      _skip();
    }
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
              const Text('📍',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 64)),
              const SizedBox(height: 24),
              Text(tr('ob_location_title'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Text(
                tr('ob_location_sub'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: _requesting ? null : _request,
                child: _requesting
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(tr('ob_enable_location')),
              ),
              TextButton(
                onPressed: _skip,
                child: Text(tr('ob_skip_now')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
