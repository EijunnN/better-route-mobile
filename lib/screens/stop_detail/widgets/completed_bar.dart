import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design/tokens.dart';
import '../../../models/route_stop.dart';
import '../../../providers/providers.dart';
import '../../../widgets/app/app.dart';

/// Slim bottom bar shown when the stop has reached a terminal state
/// (completed / failed). The hero already advertises the status via
/// [StatusPill] and a [FailureBlock] surfaces the reason — this bar
/// exists only to keep a thumb-reachable "Volver" CTA, so it stays low
/// on visual weight.
class StopDetailCompletedBar extends ConsumerWidget {
  final RouteStop stop;
  final VoidCallback onBack;

  const StopDetailCompletedBar({
    super.key,
    required this.stop,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCompleted = stop.status == StopStatus.completed;
    final color = isCompleted ? AppColors.accentLive : AppColors.accentDanger;
    final icon =
        isCompleted ? Icons.check_circle_rounded : Icons.cancel_rounded;
    // Label comes from the company delivery policy (the workflow state for
    // this status), falling back to a sensible default when not loaded.
    final wfLabel = ref
        .read(workflowProvider.notifier)
        .findBySystemState(stop.status.value)
        ?.label;
    final label =
        wfLabel ?? (isCompleted ? 'Entrega completada' : 'Entrega fallida');

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
