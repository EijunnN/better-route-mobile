import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/design/tokens.dart';
import '../models/route_stop.dart';
import '../providers/providers.dart';
import '../widgets/app/app.dart';

/// End of day — shift-close summary.
///
/// Spec: `Mobile - Specs.html` § 14 · Fin del día. Pulls live values
/// from [routeProvider]: completed count and failed count. Shift hours /
/// stops-per-hour derive from real stop timestamps. Closes by logging out
/// (same flow as the home menu).
class EndOfDayScreen extends ConsumerWidget {
  const EndOfDayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ref.watch(routeProvider);
    final stops = route.stops;
    final completed = stops.where((s) => s.status.isCompleted).length;
    final failed = stops.where((s) => s.status.isFailed).length;
    final pending = stops.where((s) => !s.status.isDone).length;
    final shiftDuration = _shiftDuration(stops);

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            // Top — close button.
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.fgPrimary,
                    ),
                    onPressed: () => context.pop(),
                  ),
                  const Spacer(),
                  Text(
                    'CIERRE DE TURNO',
                    style: AppTypography.label.copyWith(
                      color: AppColors.fgTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hero stat — completed / total.
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: AppRadius.rLg,
                        border: Border.all(
                          color: AppColors.borderSubtle,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ENTREGADAS HOY',
                            style: AppTypography.label.copyWith(
                              color: AppColors.fgTertiary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '$completed',
                                style: AppTypography.statLarge.copyWith(
                                  fontSize: 56,
                                  color: AppColors.lime,
                                  letterSpacing: -2,
                                ),
                              ),
                              Text(
                                ' / ${stops.length}',
                                style: AppTypography.statLarge.copyWith(
                                  fontSize: 28,
                                  color: AppColors.fgTertiary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Progress bar.
                          LayoutBuilder(
                            builder: (context, c) {
                              final ratio = stops.isEmpty
                                  ? 0.0
                                  : completed / stops.length;
                              return Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  color: AppColors.bgSurfaceElevated,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    width: c.maxWidth * ratio,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: AppColors.lime,
                                      borderRadius:
                                          BorderRadius.circular(999),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Failed deliveries (red).
                    _BigStat(
                      label: 'NO ENTREGADAS',
                      value: '$failed',
                      tone: _BigStatTone.danger,
                      mono: true,
                    ),

                    const SizedBox(height: 12),

                    // Compact 3-up stats.
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: AppRadius.rLg,
                        border: Border.all(
                          color: AppColors.borderSubtle,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _CompactStat(
                              label: 'HORAS',
                              value: _formatHours(shiftDuration),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 36,
                            color: AppColors.borderSubtle,
                          ),
                          Expanded(
                            child: _CompactStat(
                              label: 'PARADAS/H',
                              value: _stopsPerHour(shiftDuration, completed),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Status breakdown.
                    Text(
                      'DESGLOSE',
                      style: AppTypography.label.copyWith(
                        color: AppColors.fgTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: AppRadius.rLg,
                        border: Border.all(
                          color: AppColors.borderSubtle,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          _BreakdownRow(
                            color: AppColors.lime,
                            label: 'Completadas',
                            value: '$completed',
                          ),
                          const _BreakdownDivider(),
                          _BreakdownRow(
                            color: AppColors.danger,
                            label: 'No entregadas',
                            value: '$failed',
                          ),
                          const _BreakdownDivider(),
                          _BreakdownRow(
                            color: AppColors.fgSecondary,
                            label: 'Pendientes',
                            value: '$pending',
                          ),
                        ],
                      ),
                    ),

                  ],
                ),
              ),
            ),

            // Action bar.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: AppButton(
                label: 'Cerrar turno',
                icon: Icons.logout_rounded,
                variant: AppButtonVariant.primary,
                size: AppButtonSize.lg,
                fullWidth: true,
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  ref.read(locationProvider.notifier).stopTracking();
                  ref.read(trackingProvider.notifier).stopTracking();
                  ref.read(routeProvider.notifier).clear();
                  ref.read(workflowProvider.notifier).clear();
                  ref.read(fieldDefinitionProvider.notifier).clear();
                  await ref.read(authProvider.notifier).logout();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Real elapsed shift: earliest non-null `startedAt` → latest non-null
  /// `completedAt` among terminal stops. Null when no stop has started.
  Duration? _shiftDuration(List<RouteStop> stops) {
    DateTime? earliestStart;
    DateTime? latestEnd;
    for (final s in stops) {
      final start = s.startedAt;
      if (start != null &&
          (earliestStart == null || start.isBefore(earliestStart))) {
        earliestStart = start;
      }
      if (!s.status.isDone) continue;
      final end = s.completedAt;
      if (end != null && (latestEnd == null || end.isAfter(latestEnd))) {
        latestEnd = end;
      }
    }
    if (earliestStart == null) return null;
    final end = latestEnd ?? DateTime.now();
    final d = end.difference(earliestStart);
    return d.isNegative ? Duration.zero : d;
  }

  String _formatHours(Duration? d) {
    if (d == null) return '—';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  String _stopsPerHour(Duration? d, int completed) {
    if (d == null) return '—';
    final hours = d.inMinutes / 60.0;
    if (hours == 0) return '—';
    return (completed / hours).toStringAsFixed(1);
  }
}

enum _BigStatTone { danger }

class _BigStat extends StatelessWidget {
  final String label;
  final String value;
  final _BigStatTone tone;
  final bool mono;

  const _BigStat({
    required this.label,
    required this.value,
    required this.tone,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      _BigStatTone.danger => (AppColors.dangerSoft, AppColors.danger),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.rLg,
        border: Border.all(color: fg.withValues(alpha: 0.4), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.label.copyWith(
              color: fg,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: (mono ? AppTypography.mono : AppTypography.bodyMedium)
                .copyWith(
              color: AppColors.fgPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactStat extends StatelessWidget {
  final String label;
  final String value;
  const _CompactStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Column(
        children: [
          Text(
            value,
            style: AppTypography.mono.copyWith(
              color: AppColors.fgPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.label.copyWith(
              color: AppColors.fgTertiary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  const _BreakdownRow({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: AppTypography.body.copyWith(fontSize: 14),
            ),
          ),
          Text(
            value,
            style: AppTypography.mono.copyWith(
              color: AppColors.fgPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownDivider extends StatelessWidget {
  const _BreakdownDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: AppColors.borderSubtle,
    );
  }
}
