import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design/tokens.dart';
import '../../../models/route_stop.dart';
import '../../../models/workflow_state.dart';
import '../../../providers/providers.dart';
import '../../../widgets/app/app.dart';

/// Sticky action bar at the bottom of the stop detail screen.
///
/// Picks between [_DynamicBar] (when the company has workflow states
/// configured) and [_HardcodedBar] (legacy PENDING → IN_PROGRESS →
/// COMPLETED/FAILED) automatically based on [workflowProvider].
class StopDetailActionBar extends ConsumerWidget {
  final RouteStop stop;
  final bool isProcessing;
  final VoidCallback onPrimary;
  final VoidCallback onFail;
  final Future<void> Function(RouteStop, WorkflowState) onWorkflowTransition;

  const StopDetailActionBar({
    super.key,
    required this.stop,
    required this.isProcessing,
    required this.onPrimary,
    required this.onFail,
    required this.onWorkflowTransition,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wfState = ref.watch(workflowProvider);
    if (wfState.hasStates) {
      final notifier = ref.read(workflowProvider.notifier);
      final current = stop.workflowStateId != null
          ? notifier.findById(stop.workflowStateId!)
          : notifier.findBySystemState(stop.status.value);
      if (current != null) {
        final transitions = notifier.getAvailableTransitions(current.id);
        if (transitions.isNotEmpty) {
          final sorted = [...transitions]..sort((a, b) {
              if (a.isTerminal == b.isTerminal) {
                return a.position.compareTo(b.position);
              }
              return a.isTerminal ? 1 : -1;
            });
          return _DynamicBar(
            transitions: sorted,
            isProcessing: isProcessing,
            onTap: (target) => onWorkflowTransition(stop, target),
          );
        }
      }
    }

    return _HardcodedBar(
      stop: stop,
      isProcessing: isProcessing,
      onPrimary: onPrimary,
      onFail: onFail,
    );
  }
}

class _DynamicBar extends StatelessWidget {
  final List<WorkflowState> transitions;
  final bool isProcessing;
  final void Function(WorkflowState) onTap;

  const _DynamicBar({
    required this.transitions,
    required this.isProcessing,
    required this.onTap,
  });

  IconData _icon(String state) {
    switch (state) {
      case 'PENDING':
        return Icons.schedule_rounded;
      case 'IN_PROGRESS':
        return Icons.play_arrow_rounded;
      case 'COMPLETED':
        return Icons.check_rounded;
      case 'FAILED':
        return Icons.close_rounded;
      case 'CANCELLED':
        return Icons.skip_next_rounded;
      default:
        return Icons.circle_outlined;
    }
  }

  AppButtonVariant _variant(WorkflowState state, bool isPrimary) {
    if (state.isFailed || state.isCancelled) return AppButtonVariant.destructive;
    if (state.systemState == 'COMPLETED') return AppButtonVariant.live;
    return isPrimary ? AppButtonVariant.primary : AppButtonVariant.secondary;
  }

  @override
  Widget build(BuildContext context) {
    final primary = transitions.first;
    final secondaries = transitions.skip(1).toList();
    return _BarShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton(
            label: primary.label,
            icon: _icon(primary.systemState),
            variant: _variant(primary, true),
            size: AppButtonSize.xl,
            fullWidth: true,
            isLoading: isProcessing,
            onPressed: () => onTap(primary),
          ),
          for (final t in secondaries) ...[
            const SizedBox(height: 10),
            AppButton(
              label: t.label,
              icon: _icon(t.systemState),
              variant: _variant(t, false),
              size: AppButtonSize.lg,
              fullWidth: true,
              onPressed: isProcessing ? null : () => onTap(t),
            ),
          ],
        ],
      ),
    );
  }
}

class _HardcodedBar extends StatelessWidget {
  final RouteStop stop;
  final bool isProcessing;
  final VoidCallback onPrimary;
  final VoidCallback onFail;

  const _HardcodedBar({
    required this.stop,
    required this.isProcessing,
    required this.onPrimary,
    required this.onFail,
  });

  @override
  Widget build(BuildContext context) {
    final inProgress = stop.status.isInProgress;
    return _BarShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton(
            label: inProgress ? 'Completar entrega' : 'Iniciar entrega',
            icon: inProgress ? Icons.check_rounded : Icons.play_arrow_rounded,
            variant: inProgress
                ? AppButtonVariant.live
                : AppButtonVariant.primary,
            size: AppButtonSize.xl,
            fullWidth: true,
            isLoading: isProcessing,
            onPressed: onPrimary,
          ),
          if (inProgress) ...[
            const SizedBox(height: 10),
            AppButton(
              label: 'No se pudo entregar',
              icon: Icons.close_rounded,
              variant: AppButtonVariant.destructive,
              size: AppButtonSize.lg,
              fullWidth: true,
              onPressed: isProcessing ? null : onFail,
            ),
          ],
        ],
      ),
    );
  }
}

class _BarShell extends StatelessWidget {
  final Widget child;

  const _BarShell({required this.child});

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: child,
        ),
      ),
    );
  }
}
