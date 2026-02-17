import 'package:shadcn_flutter/shadcn_flutter.dart';
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

    final statusColor = _getStatusColor(stop);
    final isDone = stop.status.isDone;
    final isActive = stop.status.isInProgress;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        padding: EdgeInsets.zero,
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
                      left: Radius.circular(10),
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
                              color: statusColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${stop.sequence}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                  fontSize: 12,
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isDone
                                        ? theme.colorScheme.mutedForeground
                                        : theme.colorScheme.foreground,
                                  ),
                                ).semiBold(),
                                const SizedBox(height: 1),
                                Text(
                                  stop.trackingDisplay,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                  ),
                                ).xSmall().muted(),
                              ],
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Status badge
                          _StatusBadge(
                            status: stop.status,
                            workflowLabel: stop.workflowStateLabel,
                            workflowColor: stop.workflowStateColor,
                          ),

                          const SizedBox(width: 4),

                          // Chevron
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: theme.colorScheme.mutedForeground,
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
                            color: theme.colorScheme.mutedForeground,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              stop.address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ).small().muted(),
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
                                color: theme.colorScheme.mutedForeground,
                              ),

                            // Time window
                            if (stop.timeWindow?.hasWindow == true) ...[
                              if (stop.estimatedArrival != null)
                                const SizedBox(width: 10),
                              _InfoChip(
                                icon: Icons.access_time_outlined,
                                text: stop.timeWindow!.displayText,
                                color: StatusColors.inProgress,
                              ),
                            ],

                            const Spacer(),

                            // Distance
                            if (distanceText != null && !isDone)
                              _InfoChip(
                                icon: Icons.navigation_outlined,
                                text: distanceText,
                                color: theme.colorScheme.primary,
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
                              color: StatusColors.inProgress,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Tiene notas',
                              style: TextStyle(color: StatusColors.inProgress),
                            ).xSmall(),
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

  Color _getStatusColor(RouteStop stop) {
    // Use workflow state color if available
    if (stop.workflowStateColor != null) {
      final hex = stop.workflowStateColor!.replaceFirst('#', '');
      return Color(int.parse('0xFF$hex'));
    }

    // Fallback to hardcoded colors
    switch (stop.status) {
      case StopStatus.pending:
        return StatusColors.pending;
      case StopStatus.inProgress:
        return StatusColors.inProgress;
      case StopStatus.completed:
        return StatusColors.completed;
      case StopStatus.failed:
        return StatusColors.failed;
      case StopStatus.skipped:
        return StatusColors.skipped;
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
          style: TextStyle(
            color: color,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
          ),
        ).xSmall(),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final StopStatus status;
  final String? workflowLabel;
  final String? workflowColor;

  const _StatusBadge({
    required this.status,
    this.workflowLabel,
    this.workflowColor,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String text;

    // Use workflow state data if available
    if (workflowLabel != null && workflowColor != null) {
      final hex = workflowColor!.replaceFirst('#', '');
      textColor = Color(int.parse('0xFF$hex'));
      bgColor = textColor.withValues(alpha: 0.1);
      text = workflowLabel!;
    } else {
      switch (status) {
        case StopStatus.pending:
          bgColor = StatusColors.pendingBg;
          textColor = StatusColors.pending;
          text = 'Pendiente';
        case StopStatus.inProgress:
          bgColor = StatusColors.inProgressBg;
          textColor = StatusColors.inProgress;
          text = 'En curso';
        case StopStatus.completed:
          bgColor = StatusColors.completedBg;
          textColor = StatusColors.completed;
          text = 'Entregado';
        case StopStatus.failed:
          bgColor = StatusColors.failedBg;
          textColor = StatusColors.failed;
          text = 'Fallido';
        case StopStatus.skipped:
          bgColor = StatusColors.skippedBg;
          textColor = StatusColors.skipped;
          text = 'Omitido';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(color: textColor),
      ).xSmall().semiBold(),
    );
  }
}
