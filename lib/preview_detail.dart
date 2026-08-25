import 'package:flutter/material.dart';

import 'models/hotspot.dart';
import 'screens/hotspot_detail_screen.dart';
import 'services/audio_service.dart';
import 'theme/dyk_theme.dart';

/// Standalone preview of the hotspot detail screen for design work.
/// Run with: flutter run -t lib/preview_detail.dart -d chrome
void main() {
  runApp(const _PreviewApp());
}

const _sample = Hotspot(
  id: 'preview',
  name: 'Catedral de Mallorca',
  subtitle: 'La Seu • Founded 1229',
  description:
      'The cathedral was built on the orders of King Jaime I after he '
      'defeated the Moors in 1229. It took over 400 years to complete this '
      'Gothic masterpiece by the waterfront. La Seu is one of the most '
      'beautiful Gothic cathedrals in the world and is visible from across '
      'the bay.',
  lat: 39.5671,
  lng: 2.6498,
  radiusMeters: 60,
  audioFile:
      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
  images: [
    'https://images.unsplash.com/photo-1558642891-54be180ea339?w=1080',
    'https://images.unsplash.com/photo-1591608971362-f08b2a75731a?w=1080',
  ],
  year: '1229',
  category: 'history',
  isFree: true,
);

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dykLightTheme(),
      darkTheme: dykDarkTheme(),
      home: HotspotDetailScreen(
        hotspot: _sample,
        audioService: AudioService(),
      ),
    );
  }
}
