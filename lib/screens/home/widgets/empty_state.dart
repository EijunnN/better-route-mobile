import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';
import '../../../widgets/app/app.dart';
import 'filters.dart';

/// Empty state per filter — message changes based on whether the user
/// is looking at "all", "pending", or "done", so the empty view always
/// feels intentional.
class HomeEmptyState extends StatelessWidget {
  final HomeStopFilter filter;
  final Future<void> Function() onRefresh;

  const HomeEmptyState({
    super.key,
    required this.filter,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final messages = {
      HomeStopFilter.all: (
        'Sin paradas',
        'No tenés paradas asignadas para hoy.',
      ),
      HomeStopFilter.pending: (
        'Todo al día',
        'Completaste todas las paradas pendientes.',
      ),
      HomeStopFilter.done: (
        'Sin completadas',
        'Todavía no marcaste paradas como completadas.',
      ),
    };
    final msg = messages[filter]!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              filter == HomeStopFilter.pending
                  ? Icons.celebration_outlined
                  : Icons.inventory_2_outlined,
              size: 32,
              color: AppColors.fgTertiary,
            ),
            const SizedBox(height: 16),
            Text(msg.$1, style: AppTypography.h3),
            const SizedBox(height: 6),
            Text(
              msg.$2,
              style: AppTypography.body
                  .copyWith(color: AppColors.fgSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            AppButton(
              label: 'Actualizar',
              icon: Icons.refresh_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: onRefresh,
            ),
          ],
        ),
      ),
    );
  }
}
