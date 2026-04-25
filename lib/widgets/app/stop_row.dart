import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/design/tokens.dart';
import '../../models/route_stop.dart';
import 'status_pill.dart';

/// Agenda-style row for a route stop. Replaces the boxy StopCard with a
/// denser, more typographic layout: sequence number set in monospace on
/// the left as a "rail", main content stacked, status pill on the right.
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
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        splashColor: AppColors.bgSurfaceHover,
        highlightColor: AppColors.bgSurface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sequence rail — monospace numeral with arrival time below.
              SizedBox(
                width: 44,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.sequence.toString().padLeft(2, '0'),
                      style: AppTypography.statMedium.copyWith(
                        color: stop.status == StopStatus.completed
                            ? AppColors.fgTertiary
                            : AppColors.fgPrimary,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _arrivalLabel(),
                      style: AppTypography.monoSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Body.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.displayName,
                      style: AppTypography.bodyMedium.copyWith(
                        color: stop.status == StopStatus.completed
                            ? AppColors.fgSecondary
                            : AppColors.fgPrimary,
                        decoration: stop.status == StopStatus.skipped
                            ? TextDecoration.lineThrough
                            : null,
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
                        const SizedBox(width: 8),
                        Text(
                          stop.trackingDisplay,
                          style: AppTypography.monoSmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Trailing chevron, only when interactive.
              if (onTap != null) ...[
                const SizedBox(width: 8),
                Icon(
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

/// Thin separator between rows. Slimmer than a 1px border so the rows
/// breathe without being visually walled off.
class StopRowDivider extends StatelessWidget {
  const StopRowDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 78),
      child: Container(height: 1, color: AppColors.borderSubtle),
    );
  }
}
