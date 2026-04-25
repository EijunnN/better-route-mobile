import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design/tokens.dart';
import '../../../models/route_stop.dart';
import '../../../providers/providers.dart';
import '../../../widgets/app/app.dart';
import '../../../widgets/custom_fields_display.dart';
import '../../../widgets/shared/shared.dart';

/// Read-only display of order custom fields (entity=orders). The driver
/// fills route_stops fields elsewhere — this block is context.
class OrderCustomFieldsBlock extends ConsumerWidget {
  final RouteStop stop;

  const OrderCustomFieldsBlock({super.key, required this.stop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fieldDefState = ref.watch(fieldDefinitionProvider);
    if (!fieldDefState.hasDefinitions) return const SizedBox.shrink();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBubble(icon: Icons.list_alt_rounded),
              const SizedBox(width: 14),
              Text('Datos del pedido', style: AppTypography.label),
            ],
          ),
          const SizedBox(height: 12),
          CustomFieldsDisplay(
            customFields: stop.order!.customFields,
            definitions: fieldDefState.orderFields,
          ),
        ],
      ),
    );
  }
}
