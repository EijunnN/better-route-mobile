/// Field definition model from backend custom fields configuration
class FieldDefinition {
  final String id;
  final String entity;
  final String code;
  final String label;
  final String fieldType;
  final bool required;
  final String? placeholder;
  final List<String>? options;
  final String? defaultValue;
  final int position;
  final bool showInMobile;
  final Map<String, dynamic>? validationRules;

  const FieldDefinition({
    required this.id,
    required this.entity,
    required this.code,
    required this.label,
    required this.fieldType,
    this.required = false,
    this.placeholder,
    this.options,
    this.defaultValue,
    this.position = 0,
    this.showInMobile = true,
    this.validationRules,
  });

  factory FieldDefinition.fromJson(Map<String, dynamic> json) {
    return FieldDefinition(
      id: json['id'] as String,
      entity: json['entity'] as String? ?? 'orders',
      code: json['code'] as String,
      label: json['label'] as String,
      fieldType: json['fieldType'] as String? ?? 'text',
      required: json['required'] as bool? ?? false,
      placeholder: json['placeholder'] as String?,
      options: json['options'] != null
          ? List<String>.from(json['options'] as List)
          : null,
      defaultValue: json['defaultValue'] as String?,
      position: json['position'] as int? ?? 0,
      showInMobile: json['showInMobile'] as bool? ?? true,
      validationRules: json['validationRules'] != null
          ? Map<String, dynamic>.from(json['validationRules'] as Map)
          : null,
    );
  }

  bool get isText => fieldType == 'text';
  bool get isNumber => fieldType == 'number';
  bool get isSelect => fieldType == 'select';
  bool get isDate => fieldType == 'date';
  bool get isCurrency => fieldType == 'currency';
  bool get isPhone => fieldType == 'phone';
  bool get isEmail => fieldType == 'email';
  bool get isBoolean => fieldType == 'boolean';

  bool get hasOptions => options != null && options!.isNotEmpty;
}
