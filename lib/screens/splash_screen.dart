import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/design/tokens.dart';
import '../providers/auth_provider.dart';

/// Splash — "Cargando tu ruta del día".
///
/// Spec: `Mobile - Specs.html` § 07 / 00 · Splash, mirrored from the
/// design's `MobSplash` component. The visual language is the same as
/// the app's hero state — a stylised route polyline drawing itself,
/// stop dots popping in, and a final pulsing ring on the destination.
///
/// Timeline (1.4s, then loop-ring + shimmer dots):
///   t=0.0s  grid + glow + faint route are visible
///   t=0.2s  lime route starts drawing (dashOffset 1 → 0, 1.4s ease-out)
///   t=0.3s..1.3s  6 stop dots pop in staggered every 0.2s (scale 0.4→1.25→1)
///   t=1.4s  destination ring starts pulsing (1.6s infinite)
///   t=0.0s  logo+wordmark fade-up (600ms, runs in parallel)
///
/// Auth initialisation kicks off in parallel so the splash never lasts
/// less than a single complete intro cycle even on a fast cold-boot.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // Single timeline for the route draw + dot pops + logo fade-up.
  // Total duration covers the full intro (1.6s); the pulsing ring and
  // shimmer dots run on separate looping controllers.
  late final AnimationController _intro;

  // Pulsing destination ring — loops indefinitely once the route has
  // finished drawing.
  late final AnimationController _ring;

  // Loader shimmer (three lime dots at the bottom).
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();

    _ring = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _intro.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        _ring.repeat();
      }
    });

    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    // Give the intro a beat so brand presence registers even on a
    // warm cache. The auth init will navigate away when ready.
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    await ref.read(authProvider.notifier).initialize();
  }

  @override
  void dispose() {
    _intro.dispose();
    _ring.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Stack(
        children: [
          // Background — grid + radial lime glow. Painted once.
          const Positioned.fill(
            child: CustomPaint(painter: _SplashBackgroundPainter()),
          ),

          // Animated route illustration — vertically centred, slightly
          // above the logo so the eye lands on motion first.
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: Listenable.merge([_intro, _ring]),
                  builder: (context, _) {
                    return SizedBox(
                      width: 280,
                      height: 220,
                      child: CustomPaint(
                        painter: _SplashRoutePainter(
                          progress: _intro.value,
                          ringProgress: _ring.value,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),

                // Logo + wordmark — fade-up over 600ms at the start.
                AnimatedBuilder(
                  animation: _intro,
                  builder: (context, child) {
                    // Map [0, 0.375] of the intro controller to a full
                    // fade-up (so the fade completes in ~600ms / 1600ms).
                    final t = Curves.easeOutCubic.transform(
                      (_intro.value / 0.375).clamp(0.0, 1.0),
                    );
                    return Opacity(
                      opacity: t,
                      child: Transform.translate(
                        offset: Offset(0, (1 - t) * 8),
                        child: child,
                      ),
                    );
                  },
                  child: const _Wordmark(),
                ),
              ],
            ),
          ),

          // Bottom shimmer caption + version. Lives outside SafeArea so
          // the bottom always sits at a consistent distance from the
          // gesture inset.
          Positioned(
            left: 0,
            right: 0,
            bottom: 60,
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ShimmerDots(controller: _shimmer),
                      const SizedBox(width: 10),
                      Text(
                        'Cargando tu ruta del día',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.fgSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'v 1.0.0',
                    style: AppTypography.monoSmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Wordmark
// ─────────────────────────────────────────────────────────────────────

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: CustomPaint(painter: _MarkPainter()),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'BetterRoute',
              style: AppTypography.h2.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'DRIVER COCKPIT',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.fgTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.32,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 5;

    final top = Path()
      ..moveTo(w * 0.15, h * 0.4)
      ..lineTo(w * 0.5, h * 0.1)
      ..lineTo(w * 0.85, h * 0.4);
    final bottom = Path()
      ..moveTo(w * 0.15, h * 0.85)
      ..lineTo(w * 0.5, h * 0.55)
      ..lineTo(w * 0.85, h * 0.85);

    stroke.color = AppColors.lime;
    canvas.drawPath(top, stroke);
    stroke.color = AppColors.fgPrimary;
    canvas.drawPath(bottom, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────
// Splash background — grid + radial lime glow
// ─────────────────────────────────────────────────────────────────────

class _SplashBackgroundPainter extends CustomPainter {
  const _SplashBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Grid — 40×40 px squares, hairline lines, ~50% opacity so it
    // reads as texture not as a chart.
    final gridPaint = Paint()
      ..color = AppColors.bgSurfaceElevated.withValues(alpha: 0.5)
      ..strokeWidth = 0.6;
    const step = 40.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Radial lime glow — centred at (50%, 55%), radius 55% of width.
    final centre = Offset(size.width * 0.5, size.height * 0.55);
    final radius = size.width * 0.55;
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.lime.withValues(alpha: 0.18),
          AppColors.lime.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: centre, radius: radius));
    canvas.drawCircle(centre, radius, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────
// Animated route — drawing polyline + staggered stop dots + ring
// ─────────────────────────────────────────────────────────────────────

class _SplashRoutePainter extends CustomPainter {
  /// 0.0 → 1.0 over the full intro (1600ms).
  final double progress;

  /// 0.0 → 1.0 over the looping ring controller (1600ms).
  final double ringProgress;

  /// Raw stop coordinates in the design's 280×220 viewBox. We scale
  /// these into the actual canvas size below so the painter is
  /// resolution-agnostic.
  static const _stops = <Offset>[
    Offset(30, 170),
    Offset(80, 140),
    Offset(130, 150),
    Offset(170, 90),
    Offset(220, 110),
    Offset(250, 50),
  ];

  /// Each dot pops in at a fraction of the intro controller. The
  /// fractions correspond to ~0.3s, 0.5s, … 1.3s in the 1.6s timeline,
  /// matching the design's stagger.
  static const _popDelays = <double>[
    0.1875, // 300ms / 1600ms
    0.3125,
    0.4375,
    0.5625,
    0.6875,
    0.8125,
  ];

  /// Each dot's pop lasts ~350ms. Within `delay..delay+0.22` of the
  /// intro progress we animate scale 0.4→1.25→1.
  static const _popDuration = 0.22;

  /// Route draw begins at this point in the intro controller (≈200ms)
  /// and runs over the remaining time. Matches the design's 0.2s
  /// delay + 1.4s draw = 1.6s total.
  static const _routeStartFraction = 0.125;

  const _SplashRoutePainter({
    required this.progress,
    required this.ringProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Build the scaled point list once.
    final sx = size.width / 280;
    final sy = size.height / 220;
    final pts = _stops.map((p) => Offset(p.dx * sx, p.dy * sy)).toList();

    // 1. Faint underlay route (always at full opacity).
    final underlay = Paint()
      ..color = AppColors.borderStrong
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fullPath = _routePath(pts);
    canvas.drawPath(fullPath, underlay);

    // 2. Animated lime route — drawn from start to t (ease-out applied
    //    so the draw decelerates).
    final routeT = ((progress - _routeStartFraction) / (1 - _routeStartFraction))
        .clamp(0.0, 1.0);
    final easedT = Curves.easeOut.transform(routeT);
    if (easedT > 0) {
      final lime = Paint()
        ..color = AppColors.lime
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(_partialPath(pts, easedT), lime);
    }

    // 3. Stop dots — pop in staggered.
    for (var i = 0; i < pts.length; i++) {
      final delay = _popDelays[i];
      final localT = ((progress - delay) / _popDuration).clamp(0.0, 1.0);
      if (localT <= 0) continue;

      final scale = _popCurve(localT);
      final isStart = i == 0;
      final isEnd = i == pts.length - 1;
      final dotColor = (isStart || isEnd) ? AppColors.lime : AppColors.fgPrimary;
      final dotRadius = (isStart || isEnd ? 7.0 : 5.0) * scale;

      // White stroke under the destination so it pops against any glow.
      if (isEnd) {
        canvas.drawCircle(
          pts[i],
          dotRadius + 2 * scale,
          Paint()..color = AppColors.bgBase,
        );
      }
      canvas.drawCircle(pts[i], dotRadius, Paint()..color = dotColor);
    }

    // 4. Pulsing ring around the destination — only after the intro
    //    finishes. Radius expands 14→28, opacity 0.6→0 over 1.6s.
    final dest = pts.last;
    if (progress >= 1.0 && ringProgress > 0) {
      final ringT = ringProgress;
      final ringRadius = 14.0 + 14.0 * ringT;
      final ringOpacity = (0.6 * (1 - ringT)).clamp(0.0, 1.0);
      final ringPaint = Paint()
        ..color = AppColors.lime.withValues(alpha: ringOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(dest, ringRadius, ringPaint);
    }
  }

  /// Scale 0.4 → 1.25 → 1 with a quick overshoot, matching the
  /// design's pop keyframes (0%, 70%, 100%). Inputs are clamped to
  /// `[0, 1]` because float rounding from the outer `clamp` can land
  /// the parameter at `1.0000000000000002` once in a blue moon, and
  /// `Curves.easeOut.transform` asserts strict bounds.
  double _popCurve(double t) {
    if (t < 0.7) {
      final k = (t / 0.7).clamp(0.0, 1.0);
      return 0.4 + (1.25 - 0.4) * Curves.easeOut.transform(k);
    }
    final k = ((t - 0.7) / 0.3).clamp(0.0, 1.0);
    return 1.25 - 0.25 * Curves.easeOut.transform(k);
  }

  Path _routePath(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    return path;
  }

  /// Build a path that follows the polyline up to fraction [t] of its
  /// total length. Mirrors SVG `stroke-dashoffset` animation.
  Path _partialPath(List<Offset> pts, double t) {
    if (t <= 0) return Path();
    if (t >= 1) return _routePath(pts);

    final segments = <double>[];
    var total = 0.0;
    for (var i = 1; i < pts.length; i++) {
      final d = (pts[i] - pts[i - 1]).distance;
      segments.add(d);
      total += d;
    }
    final target = total * t;

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    var consumed = 0.0;
    for (var i = 0; i < segments.length; i++) {
      final segLen = segments[i];
      if (consumed + segLen <= target) {
        path.lineTo(pts[i + 1].dx, pts[i + 1].dy);
        consumed += segLen;
      } else {
        final remaining = target - consumed;
        final ratio = remaining / segLen;
        final p = Offset.lerp(pts[i], pts[i + 1], ratio)!;
        path.lineTo(p.dx, p.dy);
        break;
      }
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _SplashRoutePainter old) =>
      old.progress != progress || old.ringProgress != ringProgress;
}

// ─────────────────────────────────────────────────────────────────────
// Shimmer dots — three lime dots that fade in/out at staggered phases.
// ─────────────────────────────────────────────────────────────────────

class _ShimmerDots extends StatelessWidget {
  final AnimationController controller;

  const _ShimmerDots({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // 180ms stagger between dots, sine curve for the breathing.
            final phase = (controller.value - i * 0.18) % 1.0;
            final opacity = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(phase * math.pi * 2));
            return Padding(
              padding: EdgeInsets.only(right: i == 2 ? 0 : 3),
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.lime,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
