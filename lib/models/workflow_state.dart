/// Workflow state model from backend custom workflow configuration
class WorkflowState {
  final String id;
  final String code;
  final String label;
  final String systemState;
  final int position;
  final bool requiresReason;
  final bool requiresPhoto;
  final bool requiresNotes;
  final List<String>? reasonOptions;
  final bool isTerminal;
  final List<String> transitionsFrom;

  const WorkflowState({
    required this.id,
    required this.code,
    required this.label,
    required this.systemState,
    required this.position,
    this.requiresReason = false,
    this.requiresPhoto = false,
    this.requiresNotes = false,
    this.reasonOptions,
    this.isTerminal = false,
    this.transitionsFrom = const [],
  });

  bool get isFailed => systemState == 'FAILED';
}
