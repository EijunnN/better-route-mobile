import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';
import '../../../models/route_stop.dart';
import '../../../widgets/app/app.dart';
import '../../../widgets/shared/shared.dart';

/// Address + coordinates + Maps/Waze CTAs.
class LocationBlock extends StatelessWidget {
  final RouteStop stop;
  final VoidCallback onMaps;
  final VoidCallback onWaze;

  const LocationBlock({
    super.key,
    required this.stop,
    required this.onMaps,
    required this.onWaze,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBubble(icon: Icons.place_rounded),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ubicación', style: AppTypography.label),
                    const SizedBox(height: 4),
                    Text(stop.address, style: AppTypography.body),
                    const SizedBox(height: 4),
                    Text(
                      '${stop.latitude.toStringAsFixed(6)}, ${stop.longitude.toStringAsFixed(6)}',
                      style: AppTypography.monoSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Maps',
                  icon: Icons.navigation_rounded,
                  variant: AppButtonVariant.primary,
                  fullWidth: true,
                  onPressed: onMaps,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Waze',
                  icon: Icons.alt_route_rounded,
                  variant: AppButtonVariant.secondary,
                  fullWidth: true,
                  onPressed: onWaze,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
