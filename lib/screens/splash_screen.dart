import 'package:flutter/material.dart';
import '../theme/dyk_theme.dart';
import '../widgets/passim_background.dart';

/// Branded loading screen shown on launch.
///
/// The pin drops in and lands with a GPS-style ripple, then the wordmark
/// rises under it — an animation with an end, rather than a loop, because a
/// forever-pulsing logo reads as "this is taking a long time". The ripple
/// keeps going on its own while the app finishes booting, which is why there
/// is no spinner: a Material spinner under a bespoke animation looks borrowed.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  /// Height the pin falls from, and the size of the ripple stage beneath it.
  static const _dropFrom = 120.0;
  static const _pinHeight = 76.0;
  static const _stageHeight = 150.0;

  late final AnimationController _entrance;
  late final AnimationController _ripple;

  late final Animation<double> _drop;
  late final Animation<double> _squashY;
  late final Animation<double> _landRipple;
  late final Animation<double> _wordFade;
  late final Animation<double> _wordRise;

  @override
  void initState() {
    super.initState();

    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Fall accelerates (easeInCubic) — gravity, not a glide. Landing is at
    // 40% of the timeline; everything after that is the settle.
    _drop = Tween(begin: -_dropFrom, end: 0.0).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.0, 0.40, curve: Curves.easeInCubic),
      ),
    );

    // Squash on impact, then spring back. The pin has weight.
    _squashY = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 40),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.82)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 6,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.82, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 54,
      ),
    ]).animate(_entrance);

    // One sharp ring thrown off by the impact itself.
    _landRipple = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.40, 0.78, curve: Curves.easeOutCubic),
    );

    _wordFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.46, 0.86, curve: Curves.easeOut),
    );
    _wordRise = Tween(begin: 14.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.46, 0.90, curve: Curves.easeOutCubic),
      ),
    );

    // The steady "still working" signal, started once the pin has landed.
    _ripple = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _entrance.forward();
    _entrance.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) _ripple.repeat();
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    _ripple.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(passimArtwork(context)),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: passimScrim(context, strength: Scrim.light),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: _stageHeight,
                  width: 260,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      // Rings spread from the pin's tip, so they have to sit
                      // behind it in the stack.
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_entrance, _ripple]),
                          builder: (context, _) => CustomPaint(
                            painter: _RipplePainter(
                              impact: _landRipple.value,
                              idle: _ripple.isAnimating ? _ripple.value : null,
                              dark: Theme.of(context).brightness ==
                                  Brightness.dark,
                            ),
                          ),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _entrance,
                        builder: (context, child) => Transform.translate(
                          offset: Offset(0, _drop.value),
                          child: Transform(
                            alignment: Alignment.bottomCenter,
                            // Volume is roughly preserved: as it flattens it
                            // spreads, the way a dropped object does.
                            transform: Matrix4.diagonal3Values(
                              2 - _squashY.value,
                              _squashY.value,
                              1,
                            ),
                            child: child,
                          ),
                        ),
                        child: Image.asset(
                          'assets/images/passim_pin.png',
                          height: _pinHeight,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                AnimatedBuilder(
                  animation: _entrance,
                  builder: (context, child) => Opacity(
                    opacity: _wordFade.value,
                    child: Transform.translate(
                      offset: Offset(0, _wordRise.value),
                      child: child,
                    ),
                  ),
                  child: const PassimLogo(height: 44, wordmarkOnly: true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ground rings under the pin, drawn as flattened ellipses so they read as
/// lying on a surface rather than facing the viewer.
class _RipplePainter extends CustomPainter {
  /// 0→1 as the impact ring travels out; 0 before the pin lands.
  final double impact;

  /// 0→1 repeating once the app is still loading; null before that.
  final double? idle;

  /// Whether the current theme is dark — the ring colour needs to flip so
  /// it stays visible against the background.
  final bool dark;

  _RipplePainter({required this.impact, this.idle, required this.dark});

  static const _maxRadius = 108.0;

  void _ring(Canvas canvas, Offset centre, double t, double strength) {
    if (t <= 0 || t >= 1) return;
    final opacity = (1 - t) * strength;
    if (opacity <= 0.01) return;
    final radius = _maxRadius * t;
    canvas.drawOval(
      Rect.fromCenter(
        center: centre,
        width: radius * 2,
        height: radius * 0.62,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = (dark ? PassimColors.brand : PassimColors.ink)
            .withValues(alpha: opacity),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    // The pin's point, not its centre — that is where a drop would strike.
    final centre = Offset(size.width / 2, size.height - 4);

    _ring(canvas, centre, impact, 0.85);

    final idleValue = idle;
    if (idleValue != null) {
      // Two rings half a cycle apart, so the pulse never fully empties.
      _ring(canvas, centre, idleValue, 0.34);
      _ring(canvas, centre, (idleValue + 0.5) % 1.0, 0.34);
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) =>
      old.impact != impact || old.idle != idle || old.dark != dark;
}
