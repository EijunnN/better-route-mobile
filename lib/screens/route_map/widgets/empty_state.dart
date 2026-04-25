import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';

/// Map empty state — shown when the driver has no stops assigned yet.
class RouteMapEmptyState extends StatelessWidget {
  const RouteMapEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.map_outlined,
            size: 32,
            color: AppColors.fgTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            'Sin paradas para mostrar',
            style: AppTypography.body.copyWith(color: AppColors.fgSecondary),
          ),
        ],
      ),
    );
  }
}
