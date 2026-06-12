import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/hotspot.dart';
import '../services/audio_service.dart';

class PermissionScreen extends StatefulWidget {
  final List<Hotspot> hotspots;
  final AudioService audioService;
  final void Function(BuildContext)? onPermissionsGranted;

  const PermissionScreen({
    super.key,
    required this.hotspots,
    required this.audioService,
    this.onPermissionsGranted,
  });

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  bool _loading = false;

  Future<void> _requestPermissions() async {
    setState(() => _loading = true);

    final locationStatus = await Permission.locationAlways.request();
    final notifStatus = await Permission.notification.request();

    setState(() => _loading = false);

    if (!mounted) return;

    if (locationStatus.isGranted && notifStatus.isGranted) {
      widget.onPermissionsGranted?.call(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The app needs location and notification permissions to work.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '☀️',
                style: TextStyle(fontSize: 56),
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome to\nPalma Explorer',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: const Color(0xFF431407),
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                'Walk around Palma de Mallorca and discover the city\'s history as you pass historic sites.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF9A3412),
                    ),
              ),
              const SizedBox(height: 40),
              _PermissionTile(
                icon: '📍',
                title: 'Location (always on)',
                description:
                    'So we can trigger stories automatically when you\'re near a site.',
              ),
              const SizedBox(height: 16),
              _PermissionTile(
                icon: '🔔',
                title: 'Notifications',
                description:
                    'You\'ll get an alert when you\'re near a historic site.',
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _requestPermissions,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Grant permissions & start',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
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

class _PermissionTile extends StatelessWidget {
  final String icon;
  final String title;
  final String description;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF431407),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  color: Color(0xFF9A3412),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
