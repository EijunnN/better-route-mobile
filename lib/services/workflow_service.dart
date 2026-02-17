import '../models/workflow_state.dart';
import 'api_service.dart';

/// Service for loading and querying workflow states
class WorkflowService {
  static final WorkflowService _instance = WorkflowService._internal();
  factory WorkflowService() => _instance;
  WorkflowService._internal();

  final ApiService _api = ApiService();

  /// Fetch workflow states from the API
  Future<List<WorkflowState>> getWorkflowStates() async {
    final response = await _api.get('/api/mobile/driver/workflow-states');
    final List<dynamic> data = response.data['data'] as List<dynamic>;
    return data
        .map((json) => WorkflowState.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get states that the given current state can transition TO
  List<WorkflowState> getAvailableTransitions(
    List<WorkflowState> allStates,
    String currentStateId,
  ) {
    return allStates
        .where((state) => state.transitionsFrom.contains(currentStateId))
        .toList();
  }

  /// Find workflow state by its ID
  WorkflowState? findById(List<WorkflowState> allStates, String id) {
    return allStates.where((s) => s.id == id).firstOrNull;
  }

  /// Find workflow state by system state (fallback for stops without workflowStateId)
  WorkflowState? findBySystemState(
    List<WorkflowState> allStates,
    String systemState,
  ) {
    return allStates.where((s) => s.systemState == systemState).firstOrNull;
  }
}
