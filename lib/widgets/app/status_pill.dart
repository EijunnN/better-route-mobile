import 'package:flutter/material.dart';
import '../../core/design/tokens.dart';
import '../../models/route_stop.dart';

/// Compact status indicator. Live/in-progress states pulse subtly to
/// communicate motion at a glance — useful in long lists where the driver
/// scans for "what's happening right now".
class StatusPill extends StatefulWidget {
  final StopStatus status;
  final bool dense;

  const StatusPill({
    super.key,
    required this.status,
    this.dense = false,
  });

  @override
  State<StatusPill> createState() => _StatusPillState();
}

class _StatusPillState extends State<StatusPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  ({Color fg, Color bg, String label, bool pulse}) get _config {
    switch (widget.status) {
      case StopStatus.pending:
        return (
          fg: AppColors.fgSecondary,
          bg: AppColors.statusPendingBg,
          label: 'Pendiente',
          pulse: false,
        );
      case StopStatus.inProgress:
        return (
          fg: AppColors.accentLive,
          bg: AppColors.statusInProgressBg,
          label: 'En curso',
          pulse: true,
        );
      case StopStatus.completed:
        return (
          fg: AppColors.accentLive,
          bg: AppColors.statusCompletedBg,
          label: 'Completada',
          pulse: false,
        );
      case StopStatus.failed:
        return (
          fg: AppColors.accentDanger,
          bg: AppColors.statusFailedBg,
          label: 'Fallida',
          pulse: false,
        );
      case StopStatus.skipped:
        return (
          fg: AppColors.fgTertiary,
          bg: AppColors.statusSkippedBg,
          label: 'Omitida',
          pulse: false,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _config;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final glow = c.pulse
            ? [
                BoxShadow(
                  color: c.fg.withValues(
                    alpha: 0.15 + (_pulse.value * 0.25),
                  ),
                  blurRadius: 12 + (_pulse.value * 6),
                  spreadRadius: 0,
                ),
              ]
            : null;
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.dense ? 8 : 10,
            vertical: widget.dense ? 3 : 5,
          ),
          decoration: BoxDecoration(
            color: c.bg,
            borderRadius: AppRadius.rFull,
            boxShadow: glow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: widget.dense ? 5 : 6,
                height: widget.dense ? 5 : 6,
                decoration: BoxDecoration(
                  color: c.fg,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: widget.dense ? 5 : 7),
              Text(
                c.label,
                style: AppTypography.labelSmall.copyWith(
                  color: c.fg,
                  fontSize: widget.dense ? 10 : 11,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
