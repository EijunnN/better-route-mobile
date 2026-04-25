import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';
import '../../../models/route_data.dart';
import '../../../models/route_stop.dart';
import '../../../widgets/app/app.dart';

/// 2×2 KPI grid for the day's overview: pending, completed, distance,
/// duration. Reads metrics from [RouteMetrics] when available, falls
/// back to em-dashes when there's no route loaded yet.
class HomeKpiStrip extends StatelessWidget {
  final List<RouteStop> allStops;
  final RouteMetrics? metrics;

  const HomeKpiStrip({super.key, required this.allStops, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final pending = allStops.where((s) => !s.status.isDone).length;
    final done = allStops.where((s) => s.status.isDone).length;
    final distanceKm = metrics != null
        ? (metrics!.totalDistance / 1000).toStringAsFixed(1)
        : null;
    final durationMin = metrics != null
        ? (metrics!.totalDuration / 60).round().toString()
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.8,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        children: [
          KpiBlock(
            value: pending.toString(),
            label: 'Pendientes',
            icon: Icons.radio_button_unchecked_rounded,
          ),
          KpiBlock(
            value: done.toString(),
            label: 'Completadas',
            icon: Icons.check_circle_outline_rounded,
            accent: done > 0 ? AppColors.accentLive : null,
          ),
          KpiBlock(
            value: distanceKm ?? '—',
            unit: 'km',
            label: 'Distancia',
            icon: Icons.straighten_rounded,
          ),
          KpiBlock(
            value: durationMin ?? '—',
            unit: 'min',
            label: 'Duración est.',
            icon: Icons.schedule_rounded,
          ),
        ],
      ),
    );
  }
}
