import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:permission_handler/permission_handler.dart';

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

  /// Hand alignment of the overlay against the live view.
  double _scale = 1;
  Offset _offset = Offset.zero;
  double _scaleStart = 1;
  Offset _offsetStart = Offset.zero;
  Offset _focalStart = Offset.zero;

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
      // Ask before opening. The manifest entry only grants the right to ask;
      // without this the first run silently falls through to the still-image
      // fallback, which looks exactly like a broken camera rather than a
      // missing permission.
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          setState(() => _cameraError = status.isPermanentlyDenied
              ? 'Camera blocked in Settings'
              : 'Camera permission denied');
        }
        return;
      }
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final c = CameraController(back, ResolutionPreset.veryHigh,
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

  /// The shape the photographs were taken in. Both layers are drawn inside a
  /// box of this shape, letterboxed into whatever the screen is, because two
  /// layers cropped independently to two different aspect ratios can never
  /// line up however good the artwork is.
  static const _frameAspect = 4 / 3;

  @override
  Widget build(BuildContext context) {
    final view = _view;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _frameAspect,
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // The present: the live camera, cropped to the frame, or
                    // its photograph standing in when there is no camera.
                    if (_camera != null)
                      FittedBox(
                        fit: BoxFit.cover,
                        clipBehavior: Clip.hardEdge,
                        child: SizedBox(
                          // No swapping. previewSize is already reported in
                          // landscape, and this screen is locked to landscape;
                          // turning it on its side was what blew the preview up
                          // to several times its proper size.
                          width: _camera!.value.previewSize?.width ?? 4,
                          height: _camera!.value.previewSize?.height ?? 3,
                          child: CameraPreview(_camera!),
                        ),
                      )
                    else
                      Image.asset(view.now, fit: BoxFit.cover),

                    // The past, dissolved over it. Scale and offset are
                    // adjustable by hand: the photographs were taken on a
                    // different phone to the one demoing, and two lenses with
                    // different fields of view cannot be matched in code.
                    // Pinch and drag until the corners sit on the real ones.
                    Opacity(
                      opacity: _fade,
                      child: Transform.translate(
                        offset: _offset,
                        child: Transform.scale(
                          scale: _scale,
                          child: Image.asset(view.then, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Pinch to size the overlay, drag to nudge it.
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onScaleStart: (d) {
              _scaleStart = _scale;
              _offsetStart = _offset;
              _focalStart = d.focalPoint;
            },
            onScaleUpdate: (d) => setState(() {
              _scale = (_scaleStart * d.scale).clamp(0.5, 3.0);
              _offset = _offsetStart + (d.focalPoint - _focalStart);
            }),
          ),

          SafeArea(
            child: Column(
              children: [
                _topBar(view),
                const Spacer(),
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: () => _step(-1),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: () => _step(1),
          ),
          IconButton(
            tooltip: 'Reset alignment',
            icon: const Icon(Icons.center_focus_strong, color: Colors.white),
            onPressed: () => setState(() {
              _scale = 1;
              _offset = Offset.zero;
            }),
          ),
                _slider(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Camera exceptions stringify to a wall of text with the class name in
  /// front. Keep the sentence, drop the packaging.
  static String _shortError(String e) {
    final cleaned = e.replaceFirst(RegExp(r'^CameraException\(|\)$'), '');
    return cleaned.length > 60 ? '${cleaned.substring(0, 60)}…' : cleaned;
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
          // The reason, not just the fact. When the live view is missing, the
          // screen looks identical to a frozen one, so the cause has to be on
          // screen or the next hour goes into guessing at it.
          if (_cameraError != null)
            Flexible(
              child: chip('Showing today\'s photo — ${_shortError(_cameraError!)}'),
            ),
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
