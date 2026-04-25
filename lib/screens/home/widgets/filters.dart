import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/design/tokens.dart';

/// Three-way segmented control: Todas / Pendientes / Hechas.
/// Pill-shaped chips with the selected one filled white and a small
/// monospace count next to the label.
enum HomeStopFilter { all, pending, done }

class HomeFilters extends StatelessWidget {
  final HomeStopFilter current;
  final Map<HomeStopFilter, int> counts;
  final ValueChanged<HomeStopFilter> onChange;

  const HomeFilters({
    super.key,
    required this.current,
    required this.counts,
    required this.onChange,
  });

  static const _labels = {
    HomeStopFilter.all: 'Todas',
    HomeStopFilter.pending: 'Pendientes',
    HomeStopFilter.done: 'Hechas',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        children: HomeStopFilter.values.map((f) {
          final selected = f == current;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChange(f);
              },
              child: AnimatedContainer(
                duration: AppMotion.fast,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: selected ? AppColors.fgPrimary : AppColors.bgSurface,
                  borderRadius: AppRadius.rFull,
                  border: Border.all(
                    color: selected
                        ? AppColors.fgPrimary
                        : AppColors.borderSubtle,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _labels[f]!,
                      style: AppTypography.label.copyWith(
                        color: selected
                            ? AppColors.fgInverse
                            : AppColors.fgPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      counts[f].toString(),
                      style: AppTypography.monoSmall.copyWith(
                        color: selected
                            ? AppColors.fgInverse.withValues(alpha: 0.6)
                            : AppColors.fgTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
