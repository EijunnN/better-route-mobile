import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';
import '../../../models/route_stop.dart';
import '../../../widgets/app/app.dart';
import '../../../widgets/shared/shared.dart';

/// Section block showing the customer's time window plus the route's
/// estimated arrival (when available).
///
/// Hides itself entirely when the stop has no real time window — the
/// previous version rendered `--:-- – --:--` which was visual noise.
/// ETA is also suppressed for terminal stops because by then the
/// pre-computed arrival is irrelevant (and was usually zeroed by the
/// backend, surfacing as a confusing `00:00`).
class TimeWindowBlock extends StatelessWidget {
  final RouteStop stop;

  const TimeWindowBlock({super.key, required this.stop});

  String _fmt(DateTime dt) {
    // Backend sends timestamps in UTC (`...Z`). Dart parses those as
    // `isUtc: true`, which means `dt.hour` returns UTC hours. Forcing
    // `.toLocal()` converts to the device's timezone — same hour the
    // operator typed in /orders. Without this, a 11:45 Peru window
    // showed up as 16:45 in the app because nobody converted from
    // UTC.
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final tw = stop.timeWindow;
    if (tw == null || (tw.start == null && tw.end == null)) {
      return const SizedBox.shrink();
    }

    final windowText =
        '${tw.start != null ? _fmt(tw.start!) : '--:--'} – ${tw.end != null ? _fmt(tw.end!) : '--:--'}';
    final eta = stop.estimatedArrival;
    final showEta = eta != null && !stop.status.isDone;

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
                  windowText,
                  style: AppTypography.statMedium.copyWith(fontSize: 18),
                ),
                if (showEta) ...[
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
