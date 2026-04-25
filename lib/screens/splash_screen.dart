import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/design/tokens.dart';
import '../providers/auth_provider.dart';

/// Cinematic intro: a single mark fades in over the bgBase, with a thin
/// progress bar at the bottom that completes as auth initializes. Avoids
/// the "logo + tagline + spinner" template look.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _progress;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _progress = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();

    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    await ref.read(authProvider.notifier).initialize();
  }

  @override
  void dispose() {
    _intro.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Stack(
          children: [
            // Centered mark.
            Center(
              child: AnimatedBuilder(
                animation: _intro,
                builder: (context, _) {
                  final t = Curves.easeOutCubic.transform(_intro.value);
                  return Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, (1 - t) * 12),
                      child: const _Mark(),
                    ),
                  );
                },
              ),
            ),
            // Bottom progress + version row.
            Positioned(
              left: 0,
              right: 0,
              bottom: 32,
              child: Column(
                children: [
                  _ProgressBar(controller: _progress),
                  const SizedBox(height: 14),
                  Text('v1.0.0', style: AppTypography.monoSmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // The "mark" — a stack of two simple shapes that read as both a
        // road and a chevron, deliberately abstract so it doesn't fall
        // into "delivery cliché" (truck icon).
        SizedBox(
          width: 56,
          height: 56,
          child: CustomPaint(painter: _MarkPainter()),
        ),
        const SizedBox(height: 24),
        Text(
          'BetterRoute',
          style: AppTypography.h1.copyWith(letterSpacing: -1.0),
        ),
        const SizedBox(height: 4),
        Text(
          'Driver Cockpit',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.fgTertiary,
            letterSpacing: 4,
          ),
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
    // Two stacked chevrons, top one in jade, bottom one in white. Reads
    // as motion and direction.
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 6;

    final top = Path()
      ..moveTo(w * 0.15, h * 0.4)
      ..lineTo(w * 0.5, h * 0.1)
      ..lineTo(w * 0.85, h * 0.4);

    final bottom = Path()
      ..moveTo(w * 0.15, h * 0.85)
      ..lineTo(w * 0.5, h * 0.55)
      ..lineTo(w * 0.85, h * 0.85);

    stroke.color = AppColors.accentLive;
    canvas.drawPath(top, stroke);

    stroke.color = AppColors.fgPrimary;
    canvas.drawPath(bottom, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ProgressBar extends StatelessWidget {
  final AnimationController controller;

  const _ProgressBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 80),
      height: 2,
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: AppRadius.rFull,
      ),
      child: ClipRRect(
        borderRadius: AppRadius.rFull,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            return Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: Curves.easeOutCubic.transform(controller.value),
                heightFactor: 1,
                child: Container(color: AppColors.fgPrimary),
              ),
            );
          },
        ),
      ),
    );
  }
}
