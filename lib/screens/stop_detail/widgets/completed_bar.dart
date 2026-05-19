import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';
import '../../../models/route_stop.dart';
import '../../../widgets/app/app.dart';

/// Slim bottom bar shown when the stop has reached a terminal state
/// (completed / failed / skipped). The hero already advertises the
/// status via [StatusPill] and a [FailureBlock] surfaces the reason —
/// this bar exists only to keep a thumb-reachable "Volver" CTA, so it
/// stays low on visual weight.
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
      decoration: const BoxDecoration(
        color: AppColors.bgBase,
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.bodySmall.copyWith(color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
