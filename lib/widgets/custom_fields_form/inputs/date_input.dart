import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';

/// Tap-to-pick date input. Persists the value as `yyyy-MM-dd` so the
/// backend's date normalization logic accepts it without further work.
class DateInput extends StatelessWidget {
  final String? value;
  final String placeholder;
  final ValueChanged<String?> onChanged;

  const DateInput({
    super.key,
    required this.value,
    required this.placeholder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final parsed = value != null ? DateTime.tryParse(value!) : null;
    final display = parsed != null
        ? '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}'
        : placeholder;

    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: parsed ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          final iso = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
          onChanged(iso);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: AppRadius.rSm,
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: AppColors.fgTertiary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                display,
                style: AppTypography.body.copyWith(
                  color: parsed != null
                      ? AppColors.fgPrimary
                      : AppColors.fgTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
