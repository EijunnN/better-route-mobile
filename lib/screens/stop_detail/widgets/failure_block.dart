import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';

/// Banner shown when the stop is in [StopStatus.failed] state. Surfaces
/// the human-readable failure reason so the operator (and the driver
/// re-checking history) sees why it didn't go through.
///
/// [reason] is the verbatim per-company policy string stored on the stop
/// (free text) — rendered directly, no code/enum lookup.
class FailureBlock extends StatelessWidget {
  final String reason;

  const FailureBlock({super.key, required this.reason});

  @override
  Widget build(BuildContext context) {
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
                Text(reason, style: AppTypography.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
