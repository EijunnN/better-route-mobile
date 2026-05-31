import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';

/// Compact KPI card anchored at -16px from the map peek. Shows the
/// completion ratio on the left ("X /Y entregadas") and an "ETA fin"
/// on the right.
///
/// Spec: `Mobile - Specs.html` § 07 / 03 · Home.
class HomeKpiCard extends StatelessWidget {
  final int completed;
  final int total;
  final String? etaEnd;

  const HomeKpiCard({
    super.key,
    required this.completed,
    required this.total,
    this.etaEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: AppRadius.rLg,
        border: Border.all(color: AppColors.borderSubtle, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$completed',
                style: AppTypography.statMedium,
              ),
              Text(
                '/$total',
                style: AppTypography.mono.copyWith(
                  color: AppColors.fgTertiary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'entregadas',
                style: AppTypography.bodySmall,
              ),
            ],
          ),
          if (etaEnd != null)
            Text(
              'ETA fin: $etaEnd',
              style: AppTypography.monoSmall.copyWith(
                color: AppColors.fgTertiary,
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }
}
