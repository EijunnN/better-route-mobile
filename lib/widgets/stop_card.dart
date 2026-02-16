import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/location_provider.dart';

class StopCard extends ConsumerWidget {
  final RouteStop stop;
  final VoidCallback onTap;

  const StopCard({
    super.key,
    required this.stop,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final location = ref.watch(currentLocationProvider);

    // Calculate distance
    String? distanceText;
    if (location != null) {
      final locationService = ref.read(locationServiceProvider);
      final distance = locationService.distanceBetween(
        location.latitude,
        location.longitude,
        stop.latitude,
        stop.longitude,
      );
      distanceText = locationService.formatDistance(distance);
    }

    final statusColor = _getStatusColor();
    final isDone = stop.status.isDone;
    final isActive = stop.status.isInProgress;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.border,
            width: 1,
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent border for active/done states
              if (isActive || stop.status.isCompleted || stop.status.isFailed)
                Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(14),
                    ),
                  ),
                ),

              // Main content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: sequence circle + name + status badge + chevron
                      Row(
                        children: [
                          // Sequence number circle
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${stop.sequence}',
                                style: AppTypography.labelMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Name and tracking
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stop.displayName,
                                  style: AppTypography.titleSmall.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isDone
                                        ? AppColors.textSecondary
                                        : AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  stop.trackingDisplay,
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.textTertiary,
                                    fontFamily: 'monospace',
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Status badge
                          _StatusBadge(status: stop.status),

                          const SizedBox(width: 4),

                          // Chevron
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: AppColors.textTertiary,
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Address row
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              stop.address,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      // Bottom row: time info + distance
                      if (_hasTimeInfo || (distanceText != null && !isDone)) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            // ETA
                            if (stop.estimatedArrival != null)
                              _InfoChip(
                                icon: Icons.schedule_outlined,
                                text: stop.arrivalTimeDisplay,
                                color: AppColors.textSecondary,
                              ),

                            // Time window
                            if (stop.timeWindow?.hasWindow == true) ...[
                              if (stop.estimatedArrival != null)
                                const SizedBox(width: 10),
                              _InfoChip(
                                icon: Icons.access_time_outlined,
                                text: stop.timeWindow!.displayText,
                                color: AppColors.warning,
                              ),
                            ],

                            const Spacer(),

                            // Distance
                            if (distanceText != null && !isDone)
                              _InfoChip(
                                icon: Icons.navigation_outlined,
                                text: distanceText,
                                color: AppColors.primary,
                                bold: true,
                              ),
                          ],
                        ),
                      ],

                      // Notes indicator
                      if (stop.order?.notes != null &&
                          stop.order!.notes!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.sticky_note_2_outlined,
                              size: 12,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Tiene notas',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _hasTimeInfo =>
      stop.estimatedArrival != null ||
      (stop.timeWindow?.hasWindow == true);

  Color _getStatusColor() {
    switch (stop.status) {
      case StopStatus.pending:
        return AppColors.pending;
      case StopStatus.inProgress:
        return AppColors.primary;
      case StopStatus.completed:
        return AppColors.completed;
      case StopStatus.failed:
        return AppColors.failed;
      case StopStatus.skipped:
        return AppColors.skipped;
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final bool bold;

  const _InfoChip({
    required this.icon,
    required this.text,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(
          text,
          style: AppTypography.labelSmall.copyWith(
            color: color,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final StopStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String text;

    switch (status) {
      case StopStatus.pending:
        bgColor = AppColors.pendingBg;
        textColor = AppColors.pending;
        text = 'Pendiente';
      case StopStatus.inProgress:
        bgColor = AppColors.inProgressBg;
        textColor = AppColors.inProgress;
        text = 'En curso';
      case StopStatus.completed:
        bgColor = AppColors.completedBg;
        textColor = AppColors.completed;
        text = 'Entregado';
      case StopStatus.failed:
        bgColor = AppColors.failedBg;
        textColor = AppColors.failed;
        text = 'Fallido';
      case StopStatus.skipped:
        bgColor = AppColors.skippedBg;
        textColor = AppColors.skipped;
        text = 'Omitido';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: AppTypography.labelSmall.copyWith(
          fontWeight: FontWeight.w600,
          color: textColor,
          fontSize: 10,
        ),
      ),
    );
  }
}
