import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';
import '../../../models/route_stop.dart';
import '../../../widgets/app/app.dart';
import '../../../widgets/shared/shared.dart';

/// Section block showing the customer's time window plus the route's
/// estimated arrival (when available).
class TimeWindowBlock extends StatelessWidget {
  final RouteStop stop;

  const TimeWindowBlock({super.key, required this.stop});

  String _fmt(DateTime? dt) {
    if (dt == null) return '--:--';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final tw = stop.timeWindow!;
    final eta = stop.estimatedArrival;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconBubble(icon: Icons.schedule_rounded),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ventana horaria', style: AppTypography.label),
                const SizedBox(height: 4),
                Text(
                  '${_fmt(tw.start)} – ${_fmt(tw.end)}',
                  style: AppTypography.statMedium.copyWith(fontSize: 18),
                ),
                if (eta != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Llegada estimada: ${_fmt(eta)}',
                    style: AppTypography.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
