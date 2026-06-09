import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/hotspot.dart';
import '../services/audio_service.dart';

class PermissionScreen extends StatefulWidget {
  final List<Hotspot> hotspots;
  final AudioService audioService;
  final VoidCallback? onPermissionsGranted;

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
      widget.onPermissionsGranted?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Appen behöver plats- och notistillstånd för att fungera.',
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
                'Välkommen till\nPalma Explorer',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: const Color(0xFF431407),
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                'Gå runt i Palma de Mallorca och lär dig om stadens historia när du passerar historiska platser.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF9A3412),
                    ),
              ),
              const SizedBox(height: 40),
              _PermissionTile(
                icon: '📍',
                title: 'Platsinformation (alltid)',
                description:
                    'Så att vi kan trigga berättelser automatiskt när du är nära en plats.',
              ),
              const SizedBox(height: 16),
              _PermissionTile(
                icon: '🔔',
                title: 'Notiser',
                description:
                    'Du får ett meddelande när du är nära en historisk plats.',
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
                          'Ge tillstånd och starta',
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
