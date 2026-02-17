import '../models/field_definition.dart';
import 'api_service.dart';

/// Service for loading custom field definitions
class FieldDefinitionService {
  static final FieldDefinitionService _instance =
      FieldDefinitionService._internal();
  factory FieldDefinitionService() => _instance;
  FieldDefinitionService._internal();

  final ApiService _api = ApiService();

  /// Fetch field definitions from the API (only showInMobile=true)
  Future<List<FieldDefinition>> getFieldDefinitions() async {
    final response = await _api.get('/api/mobile/driver/field-definitions');
    final List<dynamic> data = response.data['data'] as List<dynamic>;
    return data
        .map((json) =>
            FieldDefinition.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get field definitions filtered by entity
  List<FieldDefinition> filterByEntity(
    List<FieldDefinition> definitions,
    String entity,
  ) {
    return definitions.where((d) => d.entity == entity).toList();
  }

  /// Find field definition by code
  FieldDefinition? findByCode(
    List<FieldDefinition> definitions,
    String code,
  ) {
    return definitions.where((d) => d.code == code).firstOrNull;
  }
}
