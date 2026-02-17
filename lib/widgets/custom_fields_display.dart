import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../models/field_definition.dart';

/// Widget that renders custom field values in a read-only display card
class CustomFieldsDisplay extends StatelessWidget {
  final Map<String, dynamic> customFields;
  final List<FieldDefinition> definitions;

  const CustomFieldsDisplay({
    super.key,
    required this.customFields,
    required this.definitions,
  });

  @override
  Widget build(BuildContext context) {
    if (customFields.isEmpty || definitions.isEmpty) {
      return const SizedBox.shrink();
    }

    // Only show fields that have values and matching definitions
    final visibleFields = definitions.where((def) {
      final value = customFields[def.code];
      return value != null && value.toString().isNotEmpty;
    }).toList();

    if (visibleFields.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.list_alt_outlined, size: 20),
              const SizedBox(width: 8),
              const Text('Campos adicionales').semiBold(),
            ],
          ),
          const SizedBox(height: 12),
          ...visibleFields.map((def) => _buildFieldRow(context, def)),
        ],
      ),
    );
  }

  Widget _buildFieldRow(BuildContext context, FieldDefinition def) {
    final theme = Theme.of(context);
    final value = customFields[def.code];
    final displayValue = _formatValue(def, value);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              def.label,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.mutedForeground,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              displayValue,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatValue(FieldDefinition def, dynamic value) {
    if (value == null) return '-';

    switch (def.fieldType) {
      case 'boolean':
        return value == true || value == 'true' ? 'Si' : 'No';
      case 'currency':
        final num = double.tryParse(value.toString());
        if (num != null) return '\$${num.toStringAsFixed(2)}';
        return value.toString();
      case 'number':
        final num = double.tryParse(value.toString());
        if (num != null) {
          return num == num.roundToDouble()
              ? num.toInt().toString()
              : num.toStringAsFixed(2);
        }
        return value.toString();
      default:
        return value.toString();
    }
  }
}
