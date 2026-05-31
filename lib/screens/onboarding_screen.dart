import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/design/tokens.dart';
import '../router/onboarding_bootstrap.dart';
import '../router/router.dart';
import '../widgets/app/app.dart';

/// Onboarding — three slides shown once, after the first login.
///
/// Spec: `Mobile - Specs.html` § 07 / 03-05 (mirrors `MobOnboarding`).
/// Three slides, each with a mini phone-shaped illustration of the
/// feature being introduced. Pagination dots on top, "Saltar" on the
/// upper-right (hidden on the last slide), and a primary CTA at the
/// bottom that either advances or finishes ("Empezar a entregar").
///
/// On finish: writes `onboarding_seen` to `SharedPreferences` so the
/// router will skip this screen on subsequent launches.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _index = 0;

  static const _slides = <_SlideContent>[
    _SlideContent(
      title: 'Tu ruta,\nsiempre clara',
      body: 'Ves todas tus paradas del día ordenadas, con tiempos '
          'estimados y la próxima resaltada. Sin perder tiempo decidiendo.',
    ),
    _SlideContent(
      title: 'Lo importante,\na la vista',
      body: 'Datos del cliente y notas del despacho '
          'destacados. Ya no tenés que buscar entre pantallas.',
    ),
    _SlideContent(
      title: 'Despacho\na un toque',
      body: 'Mensajes rápidos, llamada directa y respuestas prearmadas. '
          'Sin sacar las manos del volante más de lo necesario.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await OnboardingBootstrap.markSeen();
    if (!mounted) return;
    context.go(AppRoutes.permissions);
  }

  void _next() {
    if (_index == _slides.length - 1) {
      _finish();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  }

  void _back() {
    if (_index == 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _slides.length - 1;
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Stack(
        children: [
          // Slide-tinted radial glow shared across all three slides.
          const Positioned.fill(
            child: CustomPaint(painter: _OnboardingGlowPainter()),
          ),
          SafeArea(
            child: Column(
              children: [
                // Top — dots + Saltar.
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _Dots(count: _slides.length, active: _index),
                      AnimatedOpacity(
                        opacity: isLast ? 0 : 1,
                        duration: const Duration(milliseconds: 180),
                        child: TextButton(
                          onPressed: isLast ? null : _finish,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.fgSecondary,
                            minimumSize: const Size(40, 32),
                          ),
                          child: Text(
                            'Saltar',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.fgSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Slides.
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _slides.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) {
                      return _Slide(
                        index: i,
                        content: _slides[i],
                      );
                    },
                  ),
                ),

                // Bottom — back chevron from slide 2 + primary CTA.
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Row(
                    children: [
                      if (_index > 0) ...[
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: _back,
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              foregroundColor: AppColors.fgPrimary,
                              side: const BorderSide(
                                color: AppColors.borderStrong,
                                width: 1,
                              ),
                              shape: const CircleBorder(),
                            ),
                            child: const Icon(
                              Icons.chevron_left,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: AppButton(
                          label: isLast
                              ? 'Empezar a entregar'
                              : 'Siguiente',
                          trailingIcon: Icons.arrow_forward_rounded,
                          variant: AppButtonVariant.primary,
                          size: AppButtonSize.lg,
                          fullWidth: true,
                          onPressed: _next,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Single slide — illustration + overline + headline + body.
// ─────────────────────────────────────────────────────────────────────

class _SlideContent {
  final String title;
  final String body;
  const _SlideContent({required this.title, required this.body});
}

class _Slide extends StatelessWidget {
  final int index;
  final _SlideContent content;

  const _Slide({required this.index, required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),

          // Phone-shaped illustration, centred.
          Center(child: _SlideVisual(index: index)),

          const SizedBox(height: 36),

          Text(
            'PASO ${index + 1} DE 3',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.lime,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content.title,
            style: AppTypography.h1.copyWith(fontSize: 28, height: 1.15),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 320,
            child: Text(
              content.body,
              style: AppTypography.body.copyWith(
                color: AppColors.fgSecondary,
              ),
            ),
          ),

          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Per-slide visual — wraps a phone-shaped card around content.
// ─────────────────────────────────────────────────────────────────────

class _SlideVisual extends StatefulWidget {
  final int index;
  const _SlideVisual({required this.index});

  @override
  State<_SlideVisual> createState() => _SlideVisualState();
}

class _SlideVisualState extends State<_SlideVisual>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _routeDash;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _routeDash = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _routeDash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 280,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.bgSurface, AppColors.bgSurfaceElevated],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x73000000),
            blurRadius: 50,
            offset: Offset(0, 20),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: switch (widget.index) {
        0 => _SlideRoute(pulse: _pulse, routeDash: _routeDash),
        1 => const _SlideDetail(),
        _ => const _SlideChat(),
      },
    );
  }
}

// Slide 1 — map with route + 5 stops + pulse on current.
class _SlideRoute extends StatelessWidget {
  final AnimationController pulse;
  final AnimationController routeDash;
  const _SlideRoute({required this.pulse, required this.routeDash});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: Listenable.merge([pulse, routeDash]),
            builder: (context, _) {
              return CustomPaint(
                painter: _SlideRoutePainter(
                  pulseT: pulse.value,
                  dashT: routeDash.value,
                ),
              );
            },
          ),
        ),
        // Floating chip at the bottom.
        Positioned(
          left: 14,
          right: 14,
          bottom: 14,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.bgBase.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0x14FFFFFF),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: AppColors.fgPrimary,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '3',
                      style: AppTypography.mono.copyWith(
                        color: AppColors.fgInverse,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Av. Corrientes 1234',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.fgPrimary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '10:05',
                    style: AppTypography.mono.copyWith(
                      color: AppColors.lime,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SlideRoutePainter extends CustomPainter {
  final double pulseT;
  final double dashT;
  const _SlideRoutePainter({required this.pulseT, required this.dashT});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Grid 22×22.
    final grid = Paint()
      ..color = AppColors.bgSurfaceElevated
      ..strokeWidth = 0.5;
    const step = 22.0;
    for (var x = 0.0; x < w; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), grid);
    }
    for (var y = 0.0; y < h; y += step) {
      canvas.drawLine(Offset(0, y), Offset(w, y), grid);
    }

    // Stops in 220×280 design space.
    const dW = 220.0, dH = 280.0;
    final sx = w / dW;
    final sy = h / dH;
    final pts = [
      Offset(32 * sx, 250 * sy),
      Offset(60 * sx, 210 * sy),
      Offset(100 * sx, 200 * sy),
      Offset(140 * sx, 150 * sy),
      Offset(110 * sx, 100 * sy),
      Offset(60 * sx, 60 * sy),
    ];

    // Route shadow underneath.
    final shadow = Paint()
      ..color = const Color(0x73000000)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, shadow);

    // Animated dashed lime route.
    final lime = Paint()
      ..color = AppColors.lime
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final offset = -32 * dashT;
    _drawDashedPath(canvas, path, lime, dash: 6, gap: 4, phase: offset);

    // Stops.
    for (var i = 0; i < pts.length; i++) {
      final p = pts[i];
      final isStart = i == 0;
      final isCurrent = i == 3;
      if (isCurrent) {
        // Pulsing ring around the current stop (animated).
        final pulseR = 11 + 12 * pulseT;
        final pulseO = (0.5 * (1 - pulseT)).clamp(0.0, 1.0);
        canvas.drawCircle(
          p,
          pulseR,
          Paint()
            ..color = AppColors.fgPrimary.withValues(alpha: pulseO)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        // Solid white circle + dark border + numeral.
        canvas.drawCircle(p, 11, Paint()..color = AppColors.fgPrimary);
        canvas.drawCircle(
          p,
          11,
          Paint()
            ..color = AppColors.bgBase
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        final tp = TextPainter(
          text: TextSpan(
            text: '3',
            style: AppTypography.mono.copyWith(
              color: AppColors.bgBase,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(p.dx - tp.width / 2, p.dy - tp.height / 2),
        );
      } else {
        final r = isStart ? 7.0 : 6.0;
        canvas.drawCircle(
          p,
          r,
          Paint()
            ..color = isStart ? AppColors.lime : AppColors.fgPrimary,
        );
      }
    }
  }

  void _drawDashedPath(
    Canvas canvas,
    Path source,
    Paint paint, {
    required double dash,
    required double gap,
    double phase = 0,
  }) {
    // Convert path to a list of metrics so we can hop along the
    // segments. The phase shifts the dash start so dashes appear to
    // flow.
    for (final metric in source.computeMetrics()) {
      var dist = phase % (dash + gap);
      if (dist < 0) dist += (dash + gap);
      var pen = dist;
      while (pen < metric.length) {
        final next = pen + dash;
        final extract = metric.extractPath(
          pen.clamp(0, metric.length),
          next.clamp(0, metric.length),
        );
        canvas.drawPath(extract, paint);
        pen = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SlideRoutePainter old) =>
      old.pulseT != pulseT || old.dashT != dashT;
}

// Slide 2 — customer chip + capture preview.
class _SlideDetail extends StatelessWidget {
  const _SlideDetail();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status row.
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.limeSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: AppColors.lime,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'En curso',
                      style: AppTypography.label.copyWith(
                        color: AppColors.lime,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '09:00 – 11:00',
                style: AppTypography.mono.copyWith(
                  color: AppColors.fgTertiary,
                  fontSize: 9,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Lavalle 456',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: AppColors.fgPrimary,
            ),
          ),
          const SizedBox(height: 8),
          // Customer.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.bgSurfaceElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderSubtle, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: AppColors.bgBase,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'CM',
                    style: TextStyle(
                      color: AppColors.fgPrimary,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Carlos Méndez',
                    style: TextStyle(
                      color: AppColors.fgPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Icon(
                  Icons.phone_outlined,
                  color: AppColors.fgSecondary,
                  size: 12,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Capture preview chips.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.borderStrong,
                width: 1,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AL CERRAR VAS A LLENAR',
                  style: AppTypography.label.copyWith(
                    color: AppColors.fgTertiary,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: const [
                    _DetailChip(icon: Icons.camera_alt_outlined, label: '0/3 fotos'),
                    _DetailChip(icon: Icons.person_outline, label: 'Recibió'),
                    _DetailChip(icon: Icons.check_rounded, label: 'Confirmado'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _DetailChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceElevated,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9, color: AppColors.fgSecondary),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.fgSecondary,
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }
}

// Slide 3 — chat preview.
class _SlideChat extends StatelessWidget {
  const _SlideChat();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header.
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.limeSoft,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: AppColors.lime,
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Despacho',
                      style: TextStyle(
                        color: AppColors.fgPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: AppColors.lime,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Carolina · en línea',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.fgTertiary,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Incoming bubble.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.limeSoft,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text(
                  'C',
                  style: TextStyle(
                    color: AppColors.lime,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.bgSurfaceElevated,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                      bottomLeft: Radius.circular(4),
                    ),
                  ),
                  child: const Text(
                    'Andá por Sarmiento, hay obras en Corrientes.',
                    style: TextStyle(
                      color: AppColors.fgPrimary,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Own reply.
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 7,
              ),
              decoration: const BoxDecoration(
                color: AppColors.fgPrimary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: const Text(
                'Voy en camino 👍',
                style: TextStyle(
                  color: AppColors.fgInverse,
                  fontSize: 11,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          const Spacer(),

          // Quick replies.
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: const [
              _QuickReplyChip(label: 'Cliente ausente'),
              _QuickReplyChip(label: 'Demora 10 min'),
              _QuickReplyChip(label: 'Cobré'),
            ],
          ),
          const SizedBox(height: 6),

          // Composer.
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurfaceElevated,
                    border: Border.all(
                      color: AppColors.borderSubtle,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    'Escribir…',
                    style: TextStyle(
                      color: AppColors.fgTertiary,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: AppColors.lime,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.send_rounded,
                  color: AppColors.fgInverse,
                  size: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickReplyChip extends StatelessWidget {
  final String label;
  const _QuickReplyChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceElevated,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.fgSecondary,
          fontSize: 9.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Pagination dots — animate width 6 → 22 for the active dot.
// ─────────────────────────────────────────────────────────────────────

class _Dots extends StatelessWidget {
  final int count;
  final int active;
  const _Dots({required this.count, required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final isActive = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          margin: EdgeInsets.only(right: i == count - 1 ? 0 : 6),
          width: isActive ? 22 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? AppColors.lime : AppColors.borderStrong,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Shared radial-lime glow across all slides.
// ─────────────────────────────────────────────────────────────────────

class _OnboardingGlowPainter extends CustomPainter {
  const _OnboardingGlowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width * 0.5, size.height * 0.32);
    final radius = math.max(size.width, size.height) * 0.6;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.limeDim.withValues(alpha: 0.18),
          AppColors.limeDim.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: centre, radius: radius),
      );
    canvas.drawCircle(centre, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
