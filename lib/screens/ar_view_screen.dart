import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';

import '../services/ar_scene.dart';
import '../theme/dyk_theme.dart';

/// Hold the phone up and see the place as it was.
///
/// The live camera fills the screen and the historical photograph lies over
/// it; the slider dissolves between them. The dissolve is the point — a
/// still image of the past is a picture, but watching the present turn into
/// it is the thing people react to.
///
/// Landscape, because these frames were shot that way. The orientation is
/// forced while the screen is open and restored on the way out, so a phone
/// held sideways doesn't rotate the overlay out of line with the camera.
class ArViewScreen extends StatefulWidget {
  final ArScene scene;

  const ArViewScreen({super.key, required this.scene});

  @override
  State<ArViewScreen> createState() => _ArViewScreenState();
}

class _ArViewScreenState extends State<ArViewScreen> {
  CameraController? _camera;
  String? _cameraError;
  StreamSubscription<CompassEvent>? _compass;

  /// Live heading, or null where there is no magnetometer. Shown as a number
  /// rather than used to pick the view: these test frames have placeholder
  /// bearings, so the readout exists to be written down on site — point the
  /// phone at each wall, note the degrees, and the next set of photographs
  /// can drive the choice automatically.
  double? _heading;

  /// Which view is on screen. Chosen by hand until real bearings exist.
  int _index = 0;

  /// 0 = now, 1 = then.
  double _fade = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _startCamera();
    _compass = FlutterCompass.events?.listen((e) {
      if (mounted && e.heading != null) setState(() => _heading = e.heading);
    });
  }

  Future<void> _startCamera() async {
    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final c = CameraController(back, ResolutionPreset.high,
          enableAudio: false);
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _camera = c);
    } catch (e) {
      // No camera, or permission refused. The screen still works: the
      // present-day photograph stands in for the live view. Worth keeping —
      // a black screen in front of an audience is the one outcome with no
      // way back.
      if (mounted) setState(() => _cameraError = '$e');
    }
  }

  @override
  void dispose() {
    _compass?.cancel();
    _camera?.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  ArView get _view => widget.scene.views[_index];

  void _step(int by) {
    final n = widget.scene.views.length;
    setState(() => _index = (_index + by + n) % n);
  }

  @override
  Widget build(BuildContext context) {
    final view = _view;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // The present: the live camera, or its photograph as a stand-in.
          if (_camera != null)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _camera!.value.previewSize?.height ?? 1,
                height: _camera!.value.previewSize?.width ?? 1,
                child: CameraPreview(_camera!),
              ),
            )
          else
            Image.asset(view.now, fit: BoxFit.cover),

          // The past, dissolved over it.
          Opacity(
            opacity: _fade,
            child: Image.asset(view.then, fit: BoxFit.cover),
          ),

          // Swipe anywhere to change direction, for as long as the bearings
          // are placeholders.
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (v.abs() > 200) _step(v < 0 ? 1 : -1);
            },
          ),

          SafeArea(
            child: Column(
              children: [
                _topBar(view),
                const Spacer(),
                _slider(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar(ArView view) {
    // Everything on this screen sits over a camera image of unknown
    // brightness, so it carries its own dark plate rather than trusting the
    // theme's surface.
    Widget chip(String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          chip(widget.scene.title),
          const SizedBox(width: 8),
          chip(_heading == null
              ? 'no compass'
              : '${_heading!.round()}°  ·  view ${_index + 1}/'
                  '${widget.scene.views.length}'),
          const Spacer(),
          if (_cameraError != null) chip('camera off'),
        ],
      ),
    );
  }

  Widget _slider() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
        ),
      ),
      child: Row(
        children: [
          const Text('Now',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: DykColors.yellow,
                thumbColor: DykColors.yellow,
                inactiveTrackColor: Colors.white24,
              ),
              child: Slider(
                value: _fade,
                onChanged: (v) => setState(() => _fade = v),
              ),
            ),
          ),
          Text(widget.scene.era,
              style: const TextStyle(
                  color: DykColors.yellow, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
