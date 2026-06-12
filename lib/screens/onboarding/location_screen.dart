import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'notifications_screen.dart';

class LocationScreen extends StatefulWidget {
  final VoidCallback onFinished;
  const LocationScreen({super.key, required this.onFinished});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  bool _requesting = false;

  Future<void> _request() async {
    setState(() => _requesting = true);
    final status = await Permission.locationAlways.request();
    setState(() => _requesting = false);
    if (!mounted) return;
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Location is needed to discover places around you. You can enable it later in Settings.'),
      ));
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => NotificationsScreen(onFinished: widget.onFinished),
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
              const Text('📍', textAlign: TextAlign.center, style: TextStyle(fontSize: 64)),
              const SizedBox(height: 24),
              Text('Location Access',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Text(
                'We use your location to discover places around you.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: _requesting ? null : _request,
                child: _requesting
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('ENABLE LOCATION'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
