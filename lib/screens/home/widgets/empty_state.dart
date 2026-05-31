import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';
import '../../../widgets/app/app.dart';
import 'filters.dart';

/// Empty state per filter — rediseño.
///
/// Spec: `Mobile - Specs.html` § 07 / 09 · Sin paradas. The shape: a
/// circular 88px icon with a pulsing lime ring around it, centered
/// copy, a "Next actions" card with two tappable rows, and a refresh
/// CTA at the bottom.
///
/// The message text varies by filter so the empty view always feels
/// intentional — "celebración" when you finished all pending, "to-do
/// list vacía" when there are no stops at all, etc.
class HomeEmptyState extends StatefulWidget {
  final HomeStopFilter filter;
  final Future<void> Function() onRefresh;

  const HomeEmptyState({
    super.key,
    required this.filter,
    required this.onRefresh,
  });

  @override
  State<HomeEmptyState> createState() => _HomeEmptyStateState();
}

class _HomeEmptyStateState extends State<HomeEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  ({String title, String body, IconData icon}) get _content {
    switch (widget.filter) {
      case HomeStopFilter.all:
        return (
          title: 'Sin paradas',
          body: 'No tenés paradas asignadas para hoy. Si esperás una '
              'ruta, chequeá tu conexión o avisá a despacho.',
          icon: Icons.inventory_2_outlined,
        );
      case HomeStopFilter.pending:
        return (
          title: '¡Todo al día!',
          body: 'Completaste todas las paradas pendientes. Buen '
              'trabajo — descansá un rato.',
          icon: Icons.celebration_outlined,
        );
      case HomeStopFilter.done:
        return (
          title: 'Sin completadas',
          body: 'Todavía no marcaste paradas como completadas. Vas a '
              'verlas acá apenas cerrés la primera entrega.',
          icon: Icons.task_alt_rounded,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _content;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: SizedBox(
                width: 132,
                height: 132,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _EmptyHeroPainter(
                        pulseT: _pulse.value,
                        icon: c.icon,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                c.title,
                style: AppTypography.h2,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: SizedBox(
                width: 280,
                child: Text(
                  c.body,
                  style: AppTypography.body.copyWith(
                    color: AppColors.fgSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            if (widget.filter == HomeStopFilter.all) ...[
              const SizedBox(height: 20),
              // Next actions — what the driver can do right now.
              Container(
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: AppRadius.rLg,
                  border:
                      Border.all(color: AppColors.borderSubtle, width: 1),
                ),
                child: Column(
                  children: [
                    _NextActionRow(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Avisar a despacho',
                      hint: 'Confirmá tu disponibilidad para hoy.',
                    ),
                    Container(
                      height: 1,
                      color: AppColors.borderSubtle,
                    ),
                    _NextActionRow(
                      icon: Icons.battery_charging_full_rounded,
                      title: 'Chequear batería y GPS',
                      hint: 'Verificá que todo esté listo para la ruta.',
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Center(
              child: AppButton(
                label: 'Actualizar ruta',
                icon: Icons.refresh_rounded,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.lg,
                onPressed: widget.onRefresh,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Static informational row — these are reminders, not actions. They were
/// previously rendered as tappable InkWell rows with a trailing chevron but
/// had no-op `onTap`s; we don't ship controls that look navigable but do
/// nothing, so they read as plain text now.
class _NextActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String hint;

  const _NextActionRow({
    required this.icon,
    required this.title,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.bgSurfaceElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: AppColors.lime),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyMedium.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hint,
                  style: AppTypography.bodySmall.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHeroPainter extends CustomPainter {
  final double pulseT;
  final IconData icon;

  const _EmptyHeroPainter({required this.pulseT, required this.icon});

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final coreR = 44.0;

    // Outer pulse ring — radius 60 → 76, opacity 0.6 → 0.
    final ringR = 60 + 16 * pulseT;
    final ringAlpha = (0.6 * (1 - pulseT)).clamp(0.0, 1.0);
    canvas.drawCircle(
      centre,
      ringR,
      Paint()
        ..color = AppColors.lime.withValues(alpha: ringAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Static mid-ring.
    canvas.drawCircle(
      centre,
      54,
      Paint()
        ..color = AppColors.lime.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Core circle.
    canvas.drawCircle(
      centre,
      coreR,
      Paint()..color = AppColors.bgSurface,
    );
    canvas.drawCircle(
      centre,
      coreR,
      Paint()
        ..color = AppColors.lime.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Material icon centred. TextPainter renders the codepoint via the
    // material font, so we don't need to import any extra asset.
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: 36,
          color: AppColors.lime,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(centre.dx - tp.width / 2, centre.dy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _EmptyHeroPainter old) =>
      old.pulseT != pulseT || old.icon != icon;
}
