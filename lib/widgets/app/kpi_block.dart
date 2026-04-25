import 'package:flutter/material.dart';
import '../../core/design/tokens.dart';

/// KPI tile used in the home overview. The big value is monospace
/// (tabular numbers), the label is sans (human). Optional [trend] shows
/// a delta vs. yesterday/last shift.
class KpiBlock extends StatelessWidget {
  final String value;
  final String label;
  final String? unit;
  final IconData? icon;
  /// Color override for the value — use sparingly, only for "live" tiles
  /// where the metric is changing right now (e.g. distance remaining
  /// while in motion).
  final Color? accent;

  const KpiBlock({
    super.key,
    required this.value,
    required this.label,
    this.unit,
    this.icon,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: AppRadius.rLg,
        border: Border.all(color: AppColors.borderSubtle, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: AppColors.fgTertiary),
                const SizedBox(width: 6),
              ],
              Text(
                label.toUpperCase(),
                style: AppTypography.overline,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: AppTypography.statMedium.copyWith(
                  color: accent ?? AppColors.fgPrimary,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Text(
                  unit!,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.fgTertiary,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
