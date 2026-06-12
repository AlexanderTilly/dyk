import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../widgets/dyk_page_route.dart';
import 'ready_screen.dart';

class NotificationsScreen extends StatefulWidget {
  final VoidCallback onFinished;
  const NotificationsScreen({super.key, required this.onFinished});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _requesting = false;

  void _next() {
    Navigator.of(context).push(DykPageRoute(
      page: ReadyScreen(onFinished: widget.onFinished),
    ));
  }

  Future<void> _request() async {
    setState(() => _requesting = true);
    await Permission.notification.request();
    setState(() => _requesting = false);
    if (!mounted) return;
    _next();
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
              const Text('🔔',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 64)),
              const SizedBox(height: 24),
              Text('Notifications',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Text(
                "Get notified when you're near something worth discovering.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: _requesting ? null : _request,
                child: _requesting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('ENABLE NOTIFICATIONS'),
              ),
              TextButton(
                onPressed: _next,
                child: const Text('Skip for now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
