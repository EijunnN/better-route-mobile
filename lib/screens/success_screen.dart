import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/design/tokens.dart';
import '../models/route_stop.dart';
import '../providers/providers.dart';
import '../router/router.dart';
import '../widgets/app/app.dart';

/// Success screen — shown right after a stop is marked COMPLETED.
///
/// Spec: `Mobile - Specs.html` § 07 / 06 · Entrega confirmada. The
/// shape: lime radial glow at 36% Y → animated check hero (concentric
/// pulsing rings + drawn check) → centred copy with timestamp +
/// receiver → summary card with completion stats → next-stop preview
/// → two CTAs (Volver al mapa, Seguir).
///
/// The screen reads the just-completed stop and the next pending stop
/// directly from [routeProvider], so it's pull-only and doesn't take
/// rich arguments — just the stop ID.
class SuccessScreen extends ConsumerStatefulWidget {
  final String completedStopId;

  const SuccessScreen({super.key, required this.completedStopId});

  @override
  ConsumerState<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends ConsumerState<SuccessScreen>
    with TickerProviderStateMixin {
  late final AnimationController _checkController;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    // Hero scale + check stroke draw over 700ms.
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    // Outer ring pulses indefinitely.
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _checkController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  RouteStop? _findCompleted(List<RouteStop> all) {
    for (final s in all) {
      if (s.id == widget.completedStopId) return s;
    }
    return null;
  }

  RouteStop? _findNext(List<RouteStop> all, RouteStop? completed) {
    final pending = [...all.where((s) => !s.status.isDone)]
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    if (pending.isEmpty) return null;
    if (completed == null) return pending.first;
    final after = pending.where((s) => s.sequence > completed.sequence).toList();
    return after.isNotEmpty ? after.first : pending.first;
  }

  @override
  Widget build(BuildContext context) {
    final routeState = ref.watch(routeProvider);
    final completed = _findCompleted(routeState.stops);
    final next = _findNext(routeState.stops, completed);

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Stack(
        children: [
          // Radial lime glow at 36% Y.
          const Positioned.fill(
            child: CustomPaint(painter: _SuccessGlowPainter()),
          ),
          SafeArea(
            child: Column(
              children: [
                // Top close button.
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: () => context.go(AppRoutes.home),
                        customBorder: const CircleBorder(),
                        child: const SizedBox(
                          width: 38,
                          height: 38,
                          child: Icon(
                            Icons.close_rounded,
                            color: AppColors.fgPrimary,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Hero check.
                AnimatedBuilder(
                  animation: Listenable.merge([_checkController, _pulseController]),
                  builder: (context, _) {
                    return SizedBox(
                      width: 160,
                      height: 160,
                      child: CustomPaint(
                        painter: _SuccessCheckPainter(
                          drawT: Curves.easeOut.transform(
                            _checkController.value,
                          ),
                          pulseT: _pulseController.value,
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                Text(
                  '¡Entregado!',
                  style: AppTypography.h1.copyWith(fontSize: 28),
                ),
                const SizedBox(height: 8),
                _CompletionSummary(stop: completed),

                const SizedBox(height: 22),

                if (completed != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _SummaryCard(stop: completed),
                  ),

                if (next != null) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _NextStopCard(
                      stop: next,
                      onTap: () => context.go(
                        AppRoutes.stopDetailPath(next.id),
                      ),
                    ),
                  ),
                ],

                const Spacer(),

                // Action bar.
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Volver al mapa',
                          variant: AppButtonVariant.secondary,
                          size: AppButtonSize.lg,
                          fullWidth: true,
                          onPressed: () => context.go(AppRoutes.routeMap),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 14,
                        child: AppButton(
                          label: next == null ? 'Cerrar' : 'Seguir',
                          trailingIcon: next == null
                              ? null
                              : Icons.arrow_forward_rounded,
                          variant: AppButtonVariant.primary,
                          size: AppButtonSize.lg,
                          fullWidth: true,
                          onPressed: () {
                            if (next != null) {
                              context.go(
                                AppRoutes.stopDetailPath(next.id),
                              );
                            } else {
                              context.go(AppRoutes.home);
                            }
                          },
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

class _CompletionSummary extends StatelessWidget {
  final RouteStop? stop;
  const _CompletionSummary({required this.stop});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final receiver = stop?.order?.customerName?.split(' ').first ?? 'el cliente';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text.rich(
        TextSpan(
          style: AppTypography.body.copyWith(color: AppColors.fgSecondary),
          children: [
            const TextSpan(text: 'Confirmado a las '),
            TextSpan(
              text: '$hh:$mm',
              style: AppTypography.mono.copyWith(
                color: AppColors.fgPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const TextSpan(text: ' · Recibió '),
            TextSpan(
              text: receiver,
              style: AppTypography.body.copyWith(
                color: AppColors.fgPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final RouteStop stop;

  const _SummaryCard({required this.stop});

  @override
  Widget build(BuildContext context) {
    // Real per-stop service time from the stop's own timestamps.
    final tiempoStr = (stop.startedAt != null && stop.completedAt != null)
        ? '${stop.completedAt!.difference(stop.startedAt!).inMinutes} min'
        : '—';

    // Real photo count from the evidence URLs captured at completion.
    final fotosStr = stop.evidenceUrls?.length.toString() ?? '0';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: AppRadius.rLg,
        border: Border.all(color: AppColors.borderSubtle, width: 1),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.lime,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: AppColors.fgInverse,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stop.address,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium,
                      ),
                      if (stop.order?.customerName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          stop.order!.customerName!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.fgTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            color: AppColors.borderSubtle,
          ),
          Row(
            children: [
              Expanded(child: _Stat(label: 'Tiempo', value: tiempoStr)),
              Container(width: 1, height: 48, color: AppColors.borderSubtle),
              Expanded(child: _Stat(label: 'Fotos', value: fotosStr)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.label.copyWith(
              color: AppColors.fgTertiary,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.fgPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NextStopCard extends StatelessWidget {
  final RouteStop stop;
  final VoidCallback onTap;

  const _NextStopCard({required this.stop, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'PRÓXIMA PARADA',
            style: AppTypography.label.copyWith(
              color: AppColors.fgTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Material(
          color: AppColors.bgSurface,
          borderRadius: AppRadius.rLg,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.rLg,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: AppRadius.rLg,
                border: Border.all(color: AppColors.borderSubtle, width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.borderStrong,
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${stop.sequence}',
                      style: AppTypography.mono.copyWith(
                        color: AppColors.fgPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stop.address,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          stop.order?.customerName ?? 'Cliente',
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.fgTertiary,
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

class _SuccessGlowPainter extends CustomPainter {
  const _SuccessGlowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width * 0.5, size.height * 0.36);
    final radius = size.width * 0.7;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.limeDim.withValues(alpha: 0.6),
          AppColors.limeDim.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: centre, radius: radius));
    canvas.drawCircle(centre, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SuccessCheckPainter extends CustomPainter {
  final double drawT; // 0..1 — checkmark draw progress
  final double pulseT; // 0..1 — outer ring pulse

  const _SuccessCheckPainter({required this.drawT, required this.pulseT});

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final coreR = 58.0;

    // Outer pulsing ring (radius grows 70 → 84, opacity 0.4 → 0).
    final pulseR = 70 + 14 * pulseT;
    final pulseAlpha = (0.4 * (1 - pulseT)).clamp(0.0, 1.0);
    canvas.drawCircle(
      centre,
      pulseR,
      Paint()
        ..color = AppColors.lime.withValues(alpha: pulseAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Mid ring (static, 40% alpha).
    canvas.drawCircle(
      centre,
      66,
      Paint()
        ..color = AppColors.lime.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Solid lime core with subtle drop shadow.
    canvas.drawCircle(
      centre,
      coreR,
      Paint()
        ..color = AppColors.lime
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
    );

    // Animated check stroke.
    final check = Path()
      ..moveTo(centre.dx - 22, centre.dy + 2)
      ..lineTo(centre.dx - 6, centre.dy + 18)
      ..lineTo(centre.dx + 22, centre.dy - 14);

    // Drawn fraction of the path.
    for (final metric in check.computeMetrics()) {
      final extract = metric.extractPath(0, metric.length * drawT);
      canvas.drawPath(
        extract,
        Paint()
          ..color = AppColors.fgInverse
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SuccessCheckPainter old) =>
      old.drawT != drawT || old.pulseT != pulseT;
}
