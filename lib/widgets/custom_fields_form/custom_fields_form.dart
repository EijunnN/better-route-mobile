import 'package:flutter/material.dart';
import '../../core/design/tokens.dart';
import '../../models/field_definition.dart';
import '../app/app.dart';
import 'inputs/inputs.dart';

/// Editable form for the company's stop-level custom fields. Renders
/// one input per [FieldDefinition], dispatching to a type-specific
/// input widget. Values flow up via [onChanged] as a flat
/// `Map<String, dynamic>` keyed by field code.
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
    // Seed defaults once for required fields the driver hasn't filled.
    for (final def in widget.definitions) {
      if (_values[def.code] == null &&
          def.defaultValue != null &&
          def.defaultValue!.isNotEmpty) {
        _values[def.code] = def.defaultValue;
      }
      if (def.isText ||
          def.isNumber ||
          def.isCurrency ||
          def.isPhone ||
          def.isEmail) {
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
    if (widget.definitions.isEmpty) return const SizedBox.shrink();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.edit_note_outlined, size: 18, color: AppColors.fgSecondary),
              SizedBox(width: 8),
            ],
          ),
          Text('Datos de la entrega', style: AppTypography.label),
          const SizedBox(height: 4),
          Text(
            'Completá la información requerida para esta entrega.',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: 14),
          ...widget.definitions.map((def) => _Field(
                definition: def,
                value: _values[def.code],
                controller: _textControllers[def.code],
                onChange: (v) => _update(def.code, v),
              )),
        ],
      ),
    );
  }
}

/// Single field row — label + (required *) + input.
class _Field extends StatelessWidget {
  final FieldDefinition definition;
  final dynamic value;
  final TextEditingController? controller;
  final ValueChanged<dynamic> onChange;

  const _Field({
    required this.definition,
    required this.value,
    required this.controller,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(definition.label, style: AppTypography.label),
              if (definition.required) ...[
                const SizedBox(width: 4),
                Text('*', style: AppTypography.label),
              ],
            ],
          ),
          const SizedBox(height: 6),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildInput() {
    if (definition.isBoolean) {
      return BooleanInput(value: value == true, onChanged: onChange);
    }
    if (definition.isSelect && definition.hasOptions) {
      return SelectInput(
        options: definition.options!,
        value: value?.toString(),
        placeholder: definition.placeholder ?? 'Seleccioná una opción',
        onChanged: onChange,
      );
    }
    if (definition.isDate) {
      return DateInput(
        value: value?.toString(),
        placeholder: definition.placeholder ?? 'Seleccioná una fecha',
        onChanged: onChange,
      );
    }

    final keyboardType = definition.isNumber || definition.isCurrency
        ? const TextInputType.numberWithOptions(decimal: true)
        : definition.isPhone
            ? TextInputType.phone
            : definition.isEmail
                ? TextInputType.emailAddress
                : TextInputType.text;
    return AppTextField(
      controller: controller,
      placeholder: definition.placeholder,
      keyboardType: keyboardType,
      onChanged: (text) {
        if (definition.isNumber || definition.isCurrency) {
          onChange(double.tryParse(text));
        } else {
          onChange(text.isEmpty ? null : text);
        }
      },
    );
  }
}

/// Returns the codes of required fields without a value in [values].
/// Used by sheets to disable submit until everything's filled.
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
