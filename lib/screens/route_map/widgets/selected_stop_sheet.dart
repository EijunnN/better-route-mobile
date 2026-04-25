import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';
import '../../../models/route_stop.dart';
import '../../../widgets/app/app.dart';

/// Bottom sheet that slides in over the map when a stop marker is
/// tapped. Shows the essentials (sequence, name, status, address) and
/// two CTAs (Detail, Navigate).
class SelectedStopSheet extends StatelessWidget {
  final RouteStop stop;
  final VoidCallback onClose;
  final void Function(RouteStop) onNavigate;
  final void Function(RouteStop) onDetails;

  const SelectedStopSheet({
    super.key,
    required this.stop,
    required this.onClose,
    required this.onNavigate,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '#${stop.sequence}',
                  style: AppTypography.statMedium.copyWith(fontSize: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    stop.displayName,
                    style: AppTypography.h4,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                StatusPill(status: stop.status, dense: true),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: AppColors.fgTertiary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    stop.address,
                    style: AppTypography.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Detalle',
                    icon: Icons.info_outline_rounded,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.lg,
                    fullWidth: true,
                    onPressed: () => onDetails(stop),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    label: 'Navegar',
                    icon: Icons.navigation_rounded,
                    variant: AppButtonVariant.primary,
                    size: AppButtonSize.lg,
                    fullWidth: true,
                    onPressed: () => onNavigate(stop),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
