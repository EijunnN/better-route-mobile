import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';
import '../../../models/route_stop.dart';

/// Banner shown when the stop is in [StopStatus.failed] state. Surfaces
/// the human-readable failure reason so the operator (and the driver
/// re-checking history) sees why it didn't go through.
class FailureBlock extends StatelessWidget {
  final String reason;

  const FailureBlock({super.key, required this.reason});

  @override
  Widget build(BuildContext context) {
    final reasonEnum = FailureReason.fromString(reason);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.statusFailedBg,
        borderRadius: AppRadius.rLg,
        border: Border.all(
          color: AppColors.accentDanger.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppColors.accentDanger,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Motivo del fallo',
                  style: AppTypography.label.copyWith(
                    color: AppColors.accentDanger,
                  ),
                ),
                const SizedBox(height: 6),
                Text(reasonEnum.label, style: AppTypography.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
