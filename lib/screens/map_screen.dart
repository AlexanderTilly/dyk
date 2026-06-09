import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/hotspot.dart';
import '../services/audio_service.dart';
import 'hotspot_detail_screen.dart';
import 'list_screen.dart';

class MapScreen extends StatefulWidget {
  final List<Hotspot> hotspots;
  final AudioService audioService;

  const MapScreen({
    super.key,
    required this.hotspots,
    required this.audioService,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _palmaCenterLat = 39.5696;
  static const _palmaCenterLng = 2.6502;

  Set<Marker> _buildMarkers() {
    return widget.hotspots.map((h) {
      return Marker(
        markerId: MarkerId(h.id),
        position: LatLng(h.lat, h.lng),
        infoWindow: InfoWindow(
          title: h.name,
          snippet: h.subtitle,
          onTap: () => _openHotspot(h),
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      );
    }).toSet();
  }

  void _openHotspot(Hotspot hotspot) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HotspotDetailScreen(
          hotspot: hotspot,
          audioService: widget.audioService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      appBar: AppBar(
        title: const Text('Palma Explorer'),
        backgroundColor: const Color(0xFFF97316),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ListScreen(
                    hotspots: widget.hotspots,
                    audioService: widget.audioService,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(_palmaCenterLat, _palmaCenterLng),
          zoom: 14,
        ),
        markers: _buildMarkers(),
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      ),
    );
  }
}
