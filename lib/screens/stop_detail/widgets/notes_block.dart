import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';

/// Customer note block. Highlighted with the warning accent so the
/// driver doesn't miss special instructions ("call before arrival",
/// "ring doorbell twice", etc.).
class NotesBlock extends StatelessWidget {
  final String notes;

  const NotesBlock({super.key, required this.notes});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentWarningDim.withValues(alpha: 0.25),
        borderRadius: AppRadius.rLg,
        border: Border.all(
          color: AppColors.accentWarning.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.sticky_note_2_outlined,
            size: 18,
            color: AppColors.accentWarning,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nota del cliente',
                  style: AppTypography.label.copyWith(
                    color: AppColors.accentWarning,
                  ),
                ),
                const SizedBox(height: 6),
                Text(notes, style: AppTypography.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
