import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/models.dart';

class MetricsHeader extends StatelessWidget {
  final RouteMetrics metrics;

  const MetricsHeader({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final isComplete = metrics.progressPercentage == 100;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        color: AppColors.surface,
      ),
      child: Column(
        children: [
          // Progress bar row
          Row(
            children: [
              // Progress bar
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: metrics.progress,
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isComplete ? AppColors.success : AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Percentage text
              Text(
                '${metrics.progressPercentage}%',
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isComplete ? AppColors.success : AppColors.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Stat pills row
          Row(
            children: [
              _StatPill(
                icon: Icons.check_circle_outline,
                value: metrics.completedStops.toString(),
                color: AppColors.success,
              ),
              const SizedBox(width: 8),
              _StatPill(
                icon: Icons.schedule_outlined,
                value: (metrics.pendingStops + metrics.inProgressStops).toString(),
                color: AppColors.warning,
              ),
              const SizedBox(width: 8),
              _StatPill(
                icon: Icons.cancel_outlined,
                value: metrics.failedStops.toString(),
                color: AppColors.error,
              ),
              const SizedBox(width: 8),
              _StatPill(
                icon: Icons.route_outlined,
                value: metrics.distanceDisplay,
                color: AppColors.info,
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
          color: color.withOpacity(0.08),
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
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
