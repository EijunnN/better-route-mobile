import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';
import '../../../models/route_stop.dart';
import '../../../widgets/app/app.dart';
import '../../../widgets/shared/shared.dart';

/// Order capacity metrics (weight / volume / units). Hidden when the
/// order has no quantitative dimensions configured.
class OrderBlock extends StatelessWidget {
  final OrderInfo order;

  const OrderBlock({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final hasMetrics = (order.weight ?? 0) > 0 ||
        (order.volume ?? 0) > 0 ||
        (order.units ?? 0) > 0;
    if (!hasMetrics) return const SizedBox.shrink();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBubble(icon: Icons.inventory_2_outlined),
              const SizedBox(width: 14),
              Text('Detalle del pedido', style: AppTypography.label),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              if ((order.weight ?? 0) > 0)
                _Metric(
                  label: 'Peso',
                  value: order.weight!.toStringAsFixed(0),
                  unit: 'kg',
                ),
              if ((order.volume ?? 0) > 0)
                _Metric(
                  label: 'Volumen',
                  value: order.volume!.toStringAsFixed(0),
                  unit: 'L',
                ),
              if ((order.units ?? 0) > 0)
                _Metric(
                  label: 'Unidades',
                  value: order.units!.toString(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;

  const _Metric({required this.label, required this.value, this.unit});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppTypography.overline),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: AppTypography.statMedium.copyWith(fontSize: 20)),
            if (unit != null) ...[
              const SizedBox(width: 4),
              Text(unit!, style: AppTypography.bodySmall),
            ],
          ],
        ),
      ],
    );
  }
}
