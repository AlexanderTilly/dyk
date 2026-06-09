import 'package:flutter/material.dart';
import 'models/hotspot.dart';
import 'services/content_repository.dart';
import 'services/audio_service.dart';
import 'services/notification_service.dart';
import 'services/geo_fencing_service.dart';
import 'screens/permission_screen.dart';
import 'screens/map_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final notificationService = NotificationService();
  await notificationService.initialize();

  final contentRepo = ContentRepository();
  final hotspots = await contentRepo.loadHotspots();

  final audioService = AudioService();
  final geoService = GeoFencingService();

  runApp(PalmaApp(
    hotspots: hotspots,
    audioService: audioService,
    geoService: geoService,
    notificationService: notificationService,
  ));
}

class PalmaApp extends StatefulWidget {
  final List<Hotspot> hotspots;
  final AudioService audioService;
  final GeoFencingService geoService;
  final NotificationService notificationService;

  const PalmaApp({
    super.key,
    required this.hotspots,
    required this.audioService,
    required this.geoService,
    required this.notificationService,
  });

  @override
  State<PalmaApp> createState() => _PalmaAppState();
}

class _PalmaAppState extends State<PalmaApp> {
  @override
  void initState() {
    super.initState();
    _startGeoMonitoring();
  }

  Future<void> _startGeoMonitoring() async {
    await widget.geoService.startMonitoring(widget.hotspots);
    widget.geoService.onHotspotEnter.listen((hotspot) {
      widget.notificationService.showHotspotNotification(
        hotspotId: hotspot.id,
        name: hotspot.name,
        year: hotspot.year,
      );
      widget.audioService.play(hotspot.audioFile);
    });
  }

  @override
  void dispose() {
    widget.audioService.dispose();
    widget.geoService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Palma Explorer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF97316),
        ),
        useMaterial3: true,
      ),
      home: PermissionScreen(
        hotspots: widget.hotspots,
        audioService: widget.audioService,
        onPermissionsGranted: (context) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => MapScreen(
                hotspots: widget.hotspots,
                audioService: widget.audioService,
              ),
            ),
          );
        },
      ),
    );
  }
}
