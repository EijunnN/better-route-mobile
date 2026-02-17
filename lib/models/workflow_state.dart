import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Workflow state model from backend custom workflow configuration
class WorkflowState {
  final String id;
  final String code;
  final String label;
  final String systemState;
  final String color;
  final String? icon;
  final int position;
  final bool requiresReason;
  final bool requiresPhoto;
  final bool requiresSignature;
  final bool requiresNotes;
  final List<String>? reasonOptions;
  final bool isTerminal;
  final List<String> transitionsFrom;

  const WorkflowState({
    required this.id,
    required this.code,
    required this.label,
    required this.systemState,
    required this.color,
    this.icon,
    required this.position,
    this.requiresReason = false,
    this.requiresPhoto = false,
    this.requiresSignature = false,
    this.requiresNotes = false,
    this.reasonOptions,
    this.isTerminal = false,
    this.transitionsFrom = const [],
  });

  factory WorkflowState.fromJson(Map<String, dynamic> json) {
    return WorkflowState(
      id: json['id'] as String,
      code: json['code'] as String,
      label: json['label'] as String,
      systemState: json['systemState'] as String,
      color: json['color'] as String,
      icon: json['icon'] as String?,
      position: json['position'] as int,
      requiresReason: json['requiresReason'] as bool? ?? false,
      requiresPhoto: json['requiresPhoto'] as bool? ?? false,
      requiresSignature: json['requiresSignature'] as bool? ?? false,
      requiresNotes: json['requiresNotes'] as bool? ?? false,
      reasonOptions: json['reasonOptions'] != null
          ? List<String>.from(json['reasonOptions'] as List)
          : null,
      isTerminal: json['isTerminal'] as bool? ?? false,
      transitionsFrom: json['transitionsFrom'] != null
          ? List<String>.from(json['transitionsFrom'] as List)
          : [],
    );
  }

  /// Parse the hex color string into a Color object
  Color get colorValue {
    final hex = color.replaceFirst('#', '');
    return Color(int.parse('0xFF$hex'));
  }

  /// Background color with low opacity for cards/badges
  Color get bgColor => colorValue.withValues(alpha: 0.1);

  bool get isCompleted => systemState == 'COMPLETED';
  bool get isFailed => systemState == 'FAILED';
  bool get isCancelled => systemState == 'CANCELLED';
  bool get isPending => systemState == 'PENDING';
  bool get isInProgress => systemState == 'IN_PROGRESS';
}
