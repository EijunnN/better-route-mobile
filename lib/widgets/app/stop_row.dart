import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/design/tokens.dart';
import '../../models/route_stop.dart';
import 'status_pill.dart';

/// Card-style row for a route stop. Each row is its own bordered
/// surface with rounded corners — replaces the previous flat list with
/// dividers because per-row cards read as discrete tap targets and
/// match the delivery-app reference designs.
///
/// Layout: monospace sequence rail on the left + arrival time below
/// it, then customer name + address + status pill / tracking ID on the
/// right, with a chevron when interactive.
class StopRow extends StatelessWidget {
  final RouteStop stop;
  final VoidCallback? onTap;

  const StopRow({
    super.key,
    required this.stop,
    this.onTap,
  });

  String _arrivalLabel() {
    final t = stop.estimatedArrival;
    if (t == null) return '--:--';
    final local = t.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = stop.status == StopStatus.completed;
    final isSkipped = stop.status == StopStatus.skipped;
    final isRevisit = stop.isRevisit;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        borderRadius: AppRadius.rLg,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: AppRadius.rLg,
            border: Border.all(
              // Revisita: borde acentuado en color "warning" para que el
              // conductor reconozca el reintento de un solo vistazo.
              color:
                  isRevisit ? AppColors.accentWarning : AppColors.borderSubtle,
              width: isRevisit ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 44,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.sequence.toString().padLeft(2, '0'),
                      style: AppTypography.statMedium.copyWith(
                        color: isCompleted
                            ? AppColors.fgTertiary
                            : AppColors.fgPrimary,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(_arrivalLabel(), style: AppTypography.monoSmall),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.displayName,
                      style: AppTypography.bodyMedium.copyWith(
                        color: isCompleted
                            ? AppColors.fgSecondary
                            : AppColors.fgPrimary,
                        decoration:
                            isSkipped ? TextDecoration.lineThrough : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stop.address,
                      style: AppTypography.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        StatusPill(status: stop.status, dense: true),
                        if (isRevisit) ...[
                          const SizedBox(width: 6),
                          _AttemptBadge(attemptNumber: stop.attemptNumber),
                        ],
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            stop.trackingDisplay,
                            style: AppTypography.monoSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.fgTertiary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// No-op placeholder kept temporarily while callsites switch to using
/// gap spacing between cards. Will be removed once the home agenda
/// migration to card-rows is verified in production.
class StopRowDivider extends StatelessWidget {
  const StopRowDivider({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(height: 10);
}

/// Pill compacto que indica que el Stop es una revisita ("Intento #N").
/// Color amber para señalar atención sin alarmar como un error.
class _AttemptBadge extends StatelessWidget {
  final int attemptNumber;
  const _AttemptBadge({required this.attemptNumber});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accentWarningDim,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.accentWarning, width: 0.5),
      ),
      child: Text(
        'Intento #$attemptNumber',
        style: AppTypography.monoSmall.copyWith(
          color: AppColors.accentWarning,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
