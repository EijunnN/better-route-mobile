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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: stop.status.isInProgress
                ? AppColors.primary
                : AppColors.border,
            width: stop.status.isInProgress ? 2 : 1,
          ),
          boxShadow: stop.status.isInProgress
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      // Sequence number
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _getStatusColor().withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '${stop.sequence}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _getStatusColor(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Customer name and tracking
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stop.displayName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                decoration: stop.status.isCompleted ||
                                        stop.status.isSkipped
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: stop.status.isDone
                                    ? AppColors.textSecondary
                                    : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              stop.trackingDisplay,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textTertiary,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Status badge
                      _StatusBadge(status: stop.status),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Address
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          stop.address,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  // Time and distance row
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Time info (ETA and/or time window)
                      Expanded(
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            // ETA
                            if (stop.estimatedArrival != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.schedule_outlined,
                                    size: 14,
                                    color: AppColors.textTertiary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    stop.arrivalTimeDisplay,
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),

                            // Time window
                            if (stop.timeWindow?.hasWindow == true)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.access_time_outlined,
                                    size: 14,
                                    color: AppColors.warning,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    stop.timeWindow!.displayText,
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),

                      // Distance
                      if (distanceText != null && !stop.status.isDone) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.navigation_outlined,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          distanceText,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Notes indicator
                  if (stop.order?.notes != null &&
                      stop.order!.notes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 12,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Tiene notas',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Action indicator
            if (!stop.status.isDone)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(15),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      stop.status.isInProgress
                          ? Icons.play_arrow_rounded
                          : Icons.touch_app_outlined,
                      size: 18,
                      color: stop.status.isInProgress
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      stop.status.isInProgress
                          ? 'Continuar entrega'
                          : 'Ver detalles',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: stop.status.isInProgress
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: stop.status.isInProgress
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

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

class _StatusBadge extends StatelessWidget {
  final StopStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String text;
    IconData icon;

    switch (status) {
      case StopStatus.pending:
        bgColor = AppColors.pendingBg;
        textColor = AppColors.pending;
        text = 'Pendiente';
        icon = Icons.schedule;
      case StopStatus.inProgress:
        bgColor = AppColors.inProgressBg;
        textColor = AppColors.inProgress;
        text = 'En curso';
        icon = Icons.play_circle_outline;
      case StopStatus.completed:
        bgColor = AppColors.completedBg;
        textColor = AppColors.completed;
        text = 'Entregado';
        icon = Icons.check_circle_outline;
      case StopStatus.failed:
        bgColor = AppColors.failedBg;
        textColor = AppColors.failed;
        text = 'Fallido';
        icon = Icons.cancel_outlined;
      case StopStatus.skipped:
        bgColor = AppColors.skippedBg;
        textColor = AppColors.skipped;
        text = 'Omitido';
        icon = Icons.skip_next;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
