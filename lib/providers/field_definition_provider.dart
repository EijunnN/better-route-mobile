import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/field_definition.dart';
import '../services/field_definition_service.dart';

/// State for field definitions
class FieldDefinitionsState {
  final List<FieldDefinition> definitions;
  final bool isLoading;
  final String? error;

  const FieldDefinitionsState({
    this.definitions = const [],
    this.isLoading = false,
    this.error,
  });

  bool get hasDefinitions => definitions.isNotEmpty;

  /// Get definitions for orders entity
  List<FieldDefinition> get orderFields =>
      definitions.where((d) => d.entity == 'orders').toList();

  /// Get definitions for route_stops entity
  List<FieldDefinition> get stopFields =>
      definitions.where((d) => d.entity == 'route_stops').toList();

  FieldDefinitionsState copyWith({
    List<FieldDefinition>? definitions,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return FieldDefinitionsState(
      definitions: definitions ?? this.definitions,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier for field definitions
class FieldDefinitionNotifier extends StateNotifier<FieldDefinitionsState> {
  final FieldDefinitionService _service;

  FieldDefinitionNotifier(this._service)
      : super(const FieldDefinitionsState());

  /// Load field definitions from API
  Future<void> loadDefinitions() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final definitions = await _service.getFieldDefinitions();
      state = state.copyWith(definitions: definitions, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error al cargar campos personalizados',
      );
    }
  }

  /// Find a field definition by code
  FieldDefinition? findByCode(String code) {
    return _service.findByCode(state.definitions, code);
  }

  /// Get definitions filtered by entity
  List<FieldDefinition> getByEntity(String entity) {
    return _service.filterByEntity(state.definitions, entity);
  }

  /// Clear state on logout
  void clear() {
    state = const FieldDefinitionsState();
  }
}

/// Field definition service provider
final fieldDefinitionServiceProvider = Provider<FieldDefinitionService>((ref) {
  return FieldDefinitionService();
});

/// Field definitions provider
final fieldDefinitionProvider = StateNotifierProvider<FieldDefinitionNotifier,
    FieldDefinitionsState>((ref) {
  final service = ref.watch(fieldDefinitionServiceProvider);
  return FieldDefinitionNotifier(service);
});
