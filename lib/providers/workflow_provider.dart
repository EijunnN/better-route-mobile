import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/workflow_state.dart';
import '../services/workflow_service.dart';

/// State for workflow states
class WorkflowStatesState {
  final List<WorkflowState> states;
  final bool isLoading;
  final String? error;

  const WorkflowStatesState({
    this.states = const [],
    this.isLoading = false,
    this.error,
  });

  bool get hasStates => states.isNotEmpty;

  WorkflowStatesState copyWith({
    List<WorkflowState>? states,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return WorkflowStatesState(
      states: states ?? this.states,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier for workflow states
class WorkflowNotifier extends StateNotifier<WorkflowStatesState> {
  final WorkflowService _service;

  WorkflowNotifier(this._service) : super(const WorkflowStatesState());

  /// Load workflow states from API
  Future<void> loadStates() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final states = await _service.getWorkflowStates();
      state = state.copyWith(states: states, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error al cargar estados de workflow',
      );
    }
  }

  /// Get available transitions for a given current state ID
  List<WorkflowState> getAvailableTransitions(String currentStateId) {
    return _service.getAvailableTransitions(state.states, currentStateId);
  }

  /// Find a workflow state by ID
  WorkflowState? findById(String id) {
    return _service.findById(state.states, id);
  }

  /// Find a workflow state by system state (fallback)
  WorkflowState? findBySystemState(String systemState) {
    return _service.findBySystemState(state.states, systemState);
  }

  /// Clear state on logout
  void clear() {
    state = const WorkflowStatesState();
  }
}

/// Workflow service provider
final workflowServiceProvider = Provider<WorkflowService>((ref) {
  return WorkflowService();
});

/// Workflow states provider
final workflowProvider =
    StateNotifierProvider<WorkflowNotifier, WorkflowStatesState>((ref) {
  final service = ref.watch(workflowServiceProvider);
  return WorkflowNotifier(service);
});
