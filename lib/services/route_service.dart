import 'dart:io';
import 'package:dio/dio.dart';
import '../core/constants.dart';
import '../models/models.dart';
import 'api_service.dart';

/// Service for route and stop management
class RouteService {
  static final RouteService _instance = RouteService._internal();
  factory RouteService() => _instance;
  RouteService._internal();

  final ApiService _api = ApiService();

  /// Get driver's route for today
  Future<DriverRouteData> getMyRoute() async {
    final response = await _api.get(ApiConfig.myRouteEndpoint);
    return DriverRouteData.fromJson(response.data as Map<String, dynamic>);
  }

  /// Update a stop's status
  Future<RouteStop> updateStopStatus({
    required String stopId,
    required StopStatus status,
    String? notes,
    FailureReason? failureReason,
    List<String>? evidenceUrls,
    String? workflowStateId,
  }) async {
    try {
      final data = <String, dynamic>{
        'status': status.value,
      };

      if (notes != null && notes.isNotEmpty) {
        data['notes'] = notes;
      }

      if (failureReason != null) {
        data['failureReason'] = failureReason.value;
      }

      if (evidenceUrls != null && evidenceUrls.isNotEmpty) {
        data['evidenceUrls'] = evidenceUrls;
      }

      if (workflowStateId != null) {
        data['workflowStateId'] = workflowStateId;
      }

      final response = await _api.patch(
        '${ApiConfig.routeStopsEndpoint}/$stopId',
        data: data,
      );

      final responseData = response.data as Map<String, dynamic>;
      return RouteStop.fromJson(responseData['data'] as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  /// Start a stop (mark as in progress)
  Future<RouteStop> startStop(String stopId, {String? workflowStateId}) async {
    return updateStopStatus(
      stopId: stopId,
      status: StopStatus.inProgress,
      workflowStateId: workflowStateId,
    );
  }

  /// Complete a stop with evidence
  Future<RouteStop> completeStop({
    required String stopId,
    required List<String> evidenceUrls,
    String? notes,
    String? workflowStateId,
  }) async {
    return updateStopStatus(
      stopId: stopId,
      status: StopStatus.completed,
      evidenceUrls: evidenceUrls,
      notes: notes,
      workflowStateId: workflowStateId,
    );
  }

  /// Fail a stop with reason
  Future<RouteStop> failStop({
    required String stopId,
    required FailureReason reason,
    List<String>? evidenceUrls,
    String? notes,
    String? workflowStateId,
  }) async {
    return updateStopStatus(
      stopId: stopId,
      status: StopStatus.failed,
      failureReason: reason,
      evidenceUrls: evidenceUrls,
      notes: notes,
      workflowStateId: workflowStateId,
    );
  }

  /// Skip a stop
  Future<RouteStop> skipStop({
    required String stopId,
    String? notes,
    String? workflowStateId,
  }) async {
    return updateStopStatus(
      stopId: stopId,
      status: StopStatus.skipped,
      notes: notes,
      workflowStateId: workflowStateId,
    );
  }

  /// Update stop with a workflow state transition (generic for dynamic states)
  Future<RouteStop> transitionStop({
    required String stopId,
    required String workflowStateId,
    required StopStatus status,
    String? notes,
    String? failureReason,
    List<String>? evidenceUrls,
  }) async {
    try {
      final data = <String, dynamic>{
        'status': status.value,
        'workflowStateId': workflowStateId,
      };

      if (notes != null && notes.isNotEmpty) {
        data['notes'] = notes;
      }

      if (failureReason != null && failureReason.isNotEmpty) {
        data['failureReason'] = failureReason;
      }

      if (evidenceUrls != null && evidenceUrls.isNotEmpty) {
        data['evidenceUrls'] = evidenceUrls;
      }

      final response = await _api.patch(
        '${ApiConfig.routeStopsEndpoint}/$stopId',
        data: data,
      );

      final responseData = response.data as Map<String, dynamic>;
      return RouteStop.fromJson(responseData['data'] as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  /// Get presigned URL for uploading evidence
  Future<PresignedUrlResponse> getPresignedUrl({
    required String trackingId,
    String contentType = 'image/jpeg',
    int? index,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'trackingId': trackingId,
        'contentType': contentType,
      };

      if (index != null) {
        queryParams['index'] = index.toString();
      }

      final response = await _api.get(
        ApiConfig.uploadEndpoint,
        queryParameters: queryParams,
      );

      return PresignedUrlResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Upload a file to presigned URL
  Future<String> uploadEvidence({
    required File file,
    required String uploadUrl,
    required String contentType,
  }) async {
    try {
      final dio = Dio();

      // Read file bytes
      final bytes = await file.readAsBytes();

      await dio.put(
        uploadUrl,
        data: bytes,
        options: Options(
          headers: {
            'Content-Type': contentType,
            'Content-Length': bytes.length,
          },
        ),
      );

      // Return the public URL (without query params)
      final publicUrl = uploadUrl.split('?').first;
      return publicUrl;
    } catch (e) {
      throw ApiException('Error al subir la imagen');
    }
  }

  /// Upload evidence photo and get public URL
  Future<String> uploadEvidencePhoto({
    required File photo,
    required String trackingId,
    int? index,
  }) async {
    // Get presigned URL
    final presigned = await getPresignedUrl(
      trackingId: trackingId,
      contentType: 'image/jpeg',
      index: index,
    );

    // Upload to presigned URL
    await uploadEvidence(
      file: photo,
      uploadUrl: presigned.uploadUrl,
      contentType: presigned.contentType,
    );

    return presigned.publicUrl;
  }
}

/// Response from presigned URL endpoint
class PresignedUrlResponse {
  final String uploadUrl;
  final String publicUrl;
  final String key;
  final int expiresIn;
  final int maxFileSize;
  final String contentType;

  const PresignedUrlResponse({
    required this.uploadUrl,
    required this.publicUrl,
    required this.key,
    required this.expiresIn,
    required this.maxFileSize,
    required this.contentType,
  });

  factory PresignedUrlResponse.fromJson(Map<String, dynamic> json) {
    return PresignedUrlResponse(
      uploadUrl: json['uploadUrl'] as String,
      publicUrl: json['publicUrl'] as String,
      key: json['key'] as String,
      expiresIn: json['expiresIn'] as int,
      maxFileSize: json['maxFileSize'] as int,
      contentType: json['contentType'] as String,
    );
  }
}
