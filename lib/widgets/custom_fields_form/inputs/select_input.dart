import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';

/// Wrap of selectable chips for fields with [FieldDefinition.options].
/// Tapping a selected chip clears the value (no implicit default).
class SelectInput extends StatelessWidget {
  final List<String> options;
  final String? value;
  final String placeholder;
  final ValueChanged<String?> onChanged;

  const SelectInput({
    super.key,
    required this.options,
    required this.value,
    required this.placeholder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final selected = value == opt;
        return GestureDetector(
          onTap: () => onChanged(selected ? null : opt),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.accentLive.withValues(alpha: 0.12)
                  : AppColors.bgSurface,
              borderRadius: AppRadius.rSm,
              border: Border.all(
                color: selected ? AppColors.accentLive : AppColors.borderSubtle,
              ),
            ),
            child: Text(
              opt,
              style: AppTypography.label.copyWith(
                color: selected ? AppColors.accentLive : AppColors.fgPrimary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
