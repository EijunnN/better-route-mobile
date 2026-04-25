import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';
import '../../../models/route_stop.dart';
import '../../../widgets/app/app.dart';

/// Sticky bottom bar shown when the stop has reached a terminal state
/// (completed / failed / skipped). Replaces the action bar — no more
/// CTAs are valid, just a "back" exit.
class StopDetailCompletedBar extends StatelessWidget {
  final RouteStop stop;
  final VoidCallback onBack;

  const StopDetailCompletedBar({
    super.key,
    required this.stop,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = stop.status == StopStatus.completed;
    final isFailed = stop.status == StopStatus.failed;
    final color = isCompleted
        ? AppColors.accentLive
        : isFailed
            ? AppColors.accentDanger
            : AppColors.fgTertiary;
    final bg = isCompleted
        ? AppColors.statusCompletedBg
        : isFailed
            ? AppColors.statusFailedBg
            : AppColors.statusSkippedBg;
    final icon = isCompleted
        ? Icons.check_circle_rounded
        : isFailed
            ? Icons.cancel_rounded
            : Icons.skip_next_rounded;
    final label = stop.workflowStateLabel ??
        (isCompleted
            ? 'Entrega completada'
            : isFailed
                ? 'Entrega fallida'
                : 'Parada omitida');

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: const Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.bodyMedium.copyWith(color: color),
                ),
              ),
              AppButton(
                label: 'Volver',
                variant: AppButtonVariant.ghost,
                onPressed: onBack,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
