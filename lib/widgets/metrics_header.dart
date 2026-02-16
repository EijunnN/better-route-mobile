import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../core/theme.dart';
import '../models/models.dart';

class MetricsHeader extends StatelessWidget {
  final RouteMetrics metrics;

  const MetricsHeader({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isComplete = metrics.progressPercentage == 100;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
      ),
      child: Column(
        children: [
          // Progress bar row
          Row(
            children: [
              // Progress bar
              Expanded(
                child: SizedBox(
                  height: 6,
                  child: LinearProgressIndicator(
                    value: metrics.progress,
                    backgroundColor: theme.colorScheme.muted,
                    color: isComplete
                        ? StatusColors.completed
                        : theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Percentage text
              Text(
                '${metrics.progressPercentage}%',
                style: TextStyle(
                  color: isComplete
                      ? StatusColors.completed
                      : theme.colorScheme.primary,
                ),
              ).semiBold(),
            ],
          ),

          const SizedBox(height: 10),

          // Stat pills row
          Row(
            children: [
              _StatPill(
                icon: Icons.check_circle_outline,
                value: metrics.completedStops.toString(),
                color: StatusColors.completed,
              ),
              const SizedBox(width: 8),
              _StatPill(
                icon: Icons.schedule_outlined,
                value: (metrics.pendingStops + metrics.inProgressStops)
                    .toString(),
                color: StatusColors.inProgress,
              ),
              const SizedBox(width: 8),
              _StatPill(
                icon: Icons.cancel_outlined,
                value: metrics.failedStops.toString(),
                color: StatusColors.failed,
              ),
              const SizedBox(width: 8),
              _StatPill(
                icon: Icons.route_outlined,
                value: metrics.distanceDisplay,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _StatPill({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color),
              ).small().bold(),
            ),
          ],
        ),
      ),
    );
  }
}
