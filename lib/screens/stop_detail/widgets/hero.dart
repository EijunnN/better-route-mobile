import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';
import '../../../models/route_stop.dart';
import '../../../widgets/app/app.dart';

/// Hero block at the top of the stop detail screen.
/// Sequence overline + customer name + status pill + address + trackingId.
class StopDetailHero extends StatelessWidget {
  final RouteStop stop;

  const StopDetailHero({super.key, required this.stop});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Parada', style: AppTypography.overline),
            const SizedBox(width: 8),
            Text(
              '#${stop.sequence.toString().padLeft(2, '0')}',
              style: AppTypography.statMedium.copyWith(
                fontSize: 16,
                color: AppColors.fgSecondary,
              ),
            ),
            const Spacer(),
            StatusPill(status: stop.status),
          ],
        ),
        const SizedBox(height: 12),
        Text(stop.displayName, style: AppTypography.h2),
        const SizedBox(height: 6),
        Text(
          stop.address,
          style: AppTypography.body.copyWith(color: AppColors.fgSecondary),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.tag_rounded, size: 14, color: AppColors.fgTertiary),
            const SizedBox(width: 4),
            Text(stop.trackingDisplay, style: AppTypography.mono),
          ],
        ),
      ],
    );
  }
}
