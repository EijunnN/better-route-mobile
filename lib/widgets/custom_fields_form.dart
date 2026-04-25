import 'package:flutter/material.dart' as material;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../models/field_definition.dart';

/// Editable counterpart of [CustomFieldsDisplay]. Renders one input per
/// [FieldDefinition], stores values in a flat `Map<String,dynamic>` keyed
/// by the field code, and surfaces missing-required-fields validation
/// through [missingRequired].
///
/// The parent (delivery sheet) reads the latest values via the [onChanged]
/// callback and forwards them to PATCH /api/route-stops/[id]?customFields=...
/// at submit time.
class CustomFieldsForm extends StatefulWidget {
  final List<FieldDefinition> definitions;
  final Map<String, dynamic> initialValues;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const CustomFieldsForm({
    super.key,
    required this.definitions,
    this.initialValues = const {},
    required this.onChanged,
  });

  @override
  State<CustomFieldsForm> createState() => _CustomFieldsFormState();
}

class _CustomFieldsFormState extends State<CustomFieldsForm> {
  late Map<String, dynamic> _values;
  final Map<String, TextEditingController> _textControllers = {};

  @override
  void initState() {
    super.initState();
    _values = {...widget.initialValues};
    // Seed default values once for required fields that the driver hasn't
    // filled yet — avoids surprising the user with an "empty required" error
    // when the company configured a defaultValue.
    for (final def in widget.definitions) {
      if (_values[def.code] == null && def.defaultValue != null && def.defaultValue!.isNotEmpty) {
        _values[def.code] = def.defaultValue;
      }
      if (def.isText || def.isNumber || def.isCurrency || def.isPhone || def.isEmail) {
        _textControllers[def.code] = TextEditingController(
          text: _values[def.code]?.toString() ?? '',
        );
      }
    }
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _update(String code, dynamic value) {
    setState(() {
      if (value == null || (value is String && value.isEmpty)) {
        _values.remove(code);
      } else {
        _values[code] = value;
      }
    });
    widget.onChanged(_values);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.definitions.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note_outlined, size: 20),
              const SizedBox(width: 8),
              const Text('Datos de la entrega').semiBold(),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Completa la información requerida para esta entrega.',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 14),
          ...widget.definitions.map((def) => _buildField(context, def)),
        ],
      ),
    );
  }

  Widget _buildField(BuildContext context, FieldDefinition def) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(def.label).small().semiBold(),
              if (def.required) ...[
                const SizedBox(width: 4),
                const Text('*').small(),
              ],
            ],
          ),
          const SizedBox(height: 6),
          _buildInput(def),
        ],
      ),
    );
  }

  Widget _buildInput(FieldDefinition def) {
    if (def.isBoolean) {
      return _BooleanInput(
        value: _values[def.code] == true,
        onChanged: (v) => _update(def.code, v),
      );
    }
    if (def.isSelect && def.hasOptions) {
      return _SelectInput(
        options: def.options!,
        value: _values[def.code]?.toString(),
        placeholder: def.placeholder ?? 'Selecciona una opción',
        onChanged: (v) => _update(def.code, v),
      );
    }
    if (def.isDate) {
      return _DateInput(
        value: _values[def.code]?.toString(),
        placeholder: def.placeholder ?? 'Selecciona una fecha',
        onChanged: (v) => _update(def.code, v),
      );
    }

    // Text-based inputs: text, number, currency, phone, email
    final controller = _textControllers[def.code]!;
    final keyboardType = def.isNumber || def.isCurrency
        ? const TextInputType.numberWithOptions(decimal: true)
        : def.isPhone
            ? TextInputType.phone
            : def.isEmail
                ? TextInputType.emailAddress
                : TextInputType.text;
    return TextField(
      controller: controller,
      placeholder: def.placeholder != null ? Text(def.placeholder!) : null,
      keyboardType: keyboardType,
      onChanged: (text) {
        if (def.isNumber || def.isCurrency) {
          final num = double.tryParse(text);
          _update(def.code, num);
        } else {
          _update(def.code, text.isEmpty ? null : text);
        }
      },
    );
  }
}

class _BooleanInput extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _BooleanInput({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Switch(value: value, onChanged: onChanged),
        const SizedBox(width: 10),
        Text(
          value ? 'Sí' : 'No',
          style: TextStyle(color: theme.colorScheme.foreground),
        ),
      ],
    );
  }
}

class _SelectInput extends StatelessWidget {
  final List<String> options;
  final String? value;
  final String placeholder;
  final ValueChanged<String?> onChanged;

  const _SelectInput({
    required this.options,
    required this.value,
    required this.placeholder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final selected = value == opt;
        return GestureDetector(
          onTap: () => onChanged(selected ? null : opt),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                  : Theme.of(context).colorScheme.muted,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.border,
              ),
            ),
            child: Text(
              opt,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.foreground,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _DateInput extends StatelessWidget {
  final String? value;
  final String placeholder;
  final ValueChanged<String?> onChanged;

  const _DateInput({
    required this.value,
    required this.placeholder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parsed = value != null ? DateTime.tryParse(value!) : null;
    final display = parsed != null
        ? '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}'
        : placeholder;

    return GestureDetector(
      onTap: () async {
        final picked = await material.showDatePicker(
          context: context,
          initialDate: parsed ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          // ISO yyyy-MM-dd — backend normaliza ambos formatos.
          final iso = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
          onChanged(iso);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.muted,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.border),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: theme.colorScheme.mutedForeground,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                display,
                style: TextStyle(
                  fontSize: 13,
                  color: parsed != null
                      ? theme.colorScheme.foreground
                      : theme.colorScheme.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Returns the codes of required fields that don't have a value in [values].
/// Useful for the parent to disable submit when there are gaps.
List<String> findMissingRequired(
  List<FieldDefinition> definitions,
  Map<String, dynamic> values,
) {
  return definitions
      .where((def) => def.required)
      .where((def) {
        final v = values[def.code];
        if (v == null) return true;
        if (v is String && v.trim().isEmpty) return true;
        return false;
      })
      .map((def) => def.code)
      .toList();
}
