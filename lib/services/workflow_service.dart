import '../core/constants.dart';
import '../models/workflow_state.dart';
import 'api_service.dart';

/// Service for loading and querying workflow states.
///
/// There is no dedicated `/workflow-states` endpoint: the state machine
/// is crystallized server-side and identical for every company. The
/// canonical contract is `GET /api/mobile/driver/delivery-policy`, which
/// returns `{ data: { policy, stateMachine: { states, transitions } } }`.
/// We reconstruct the [WorkflowState] list the rest of the app consumes
/// from that single payload:
///
///   • `states`      → SYSTEM_STATE_ORDER (the state codes, in order)
///   • `transitions` → the reachability graph (terminal = empty array)
///   • `policy`      → per-state labels/colours + evidence gates + the
///                     per-company failure-reason list.
class WorkflowService {
  static final WorkflowService _instance = WorkflowService._internal();
  factory WorkflowService() => _instance;
  WorkflowService._internal();

  final ApiService _api = ApiService();

  List<String> _cachedFailureReasons = const [];

  /// Failure reasons from the last delivery-policy fetch. The offline
  /// outbox reads this to refuse enqueueing a FAILED close without a
  /// reason (FIX-2) — empty when the policy was never loaded this session,
  /// which conservatively disables the gate.
  List<String> get cachedFailureReasons => _cachedFailureReasons;

  /// Fetch the delivery policy + state machine and project it into the
  /// flat [WorkflowState] list the UI consumes.
  Future<List<WorkflowState>> getWorkflowStates() async {
    final response = await _api.get(ApiConfig.deliveryPolicyEndpoint);
    return parseDeliveryPolicy(response.data['data'] as Map<String, dynamic>);
  }

  /// Proyección pura del payload `data` de delivery-policy (§3.8) a la
  /// lista de [WorkflowState]. Separada del fetch para que el contract-test
  /// (test/contract/, §10.5) la ejerza sobre los fixtures golden.
  List<WorkflowState> parseDeliveryPolicy(Map<String, dynamic> data) {
    final policy = data['policy'] as Map<String, dynamic>;
    final machine = data['stateMachine'] as Map<String, dynamic>;

    final states = (machine['states'] as List).cast<String>();
    final transitions = (machine['transitions'] as Map)
        .map((k, v) => MapEntry(k as String, (v as List).cast<String>()));

    final failureReasons = policy['failureReasons'] != null
        ? List<String>.from(policy['failureReasons'] as List)
        : const <String>[];
    _cachedFailureReasons = failureReasons;

    return [
      for (var i = 0; i < states.length; i++)
        _projectState(
          code: states[i],
          position: i,
          policy: policy,
          transitionsTo: transitions[states[i]] ?? const [],
          failureReasons: failureReasons,
        ),
    ];
  }

  WorkflowState _projectState({
    required String code,
    required int position,
    required Map<String, dynamic> policy,
    required List<String> transitionsTo,
    required List<String> failureReasons,
  }) {
    final labelKey = _labelKeyFor(code);
    final label = policy[labelKey] as String? ?? code;

    final completedPhoto = policy['completedRequiresPhoto'] as bool? ?? false;
    final completedNotes = policy['completedRequiresNotes'] as bool? ?? false;
    final failedPhoto = policy['failedRequiresPhoto'] as bool? ?? false;
    final failedNotes = policy['failedRequiresNotes'] as bool? ?? false;

    // Evidence gates are keyed to the COMPLETED / FAILED targets.
    final requiresPhoto = code == 'COMPLETED'
        ? completedPhoto
        : (code == 'FAILED' ? failedPhoto : false);
    final requiresNotes = code == 'COMPLETED'
        ? completedNotes
        : (code == 'FAILED' ? failedNotes : false);
    final showsReasons = code == 'FAILED';

    return WorkflowState(
      // No surrogate FK exists anymore: the state code IS the identity.
      id: code,
      code: code,
      label: label,
      systemState: code,
      position: position,
      requiresReason: showsReasons && failureReasons.isNotEmpty,
      requiresPhoto: requiresPhoto,
      requiresNotes: requiresNotes,
      reasonOptions: showsReasons ? failureReasons : null,
      isTerminal: transitionsTo.isEmpty,
      transitionsFrom: transitionsTo,
    );
  }

  String _labelKeyFor(String code) {
    switch (code) {
      case 'IN_PROGRESS':
        return 'labelInProgress';
      case 'COMPLETED':
        return 'labelCompleted';
      case 'FAILED':
        return 'labelFailed';
      default:
        return 'labelPending';
    }
  }

  /// States reachable FROM [currentStateId]. Since ids equal state codes,
  /// this returns the workflow states whose code is in the current state's
  /// transition list.
  List<WorkflowState> getAvailableTransitions(
    List<WorkflowState> allStates,
    String currentStateId,
  ) {
    final current = findById(allStates, currentStateId);
    if (current == null) return const [];
    return allStates
        .where((s) => current.transitionsFrom.contains(s.code))
        .toList();
  }

  /// Find workflow state by its ID (== state code).
  WorkflowState? findById(List<WorkflowState> allStates, String id) {
    return allStates.where((s) => s.id == id).firstOrNull;
  }

  /// Find workflow state by system state code.
  WorkflowState? findBySystemState(
    List<WorkflowState> allStates,
    String systemState,
  ) {
    return allStates.where((s) => s.systemState == systemState).firstOrNull;
  }
}
