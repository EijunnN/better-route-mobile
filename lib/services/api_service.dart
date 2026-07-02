import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/constants.dart';
import 'storage_service.dart';

/// Custom exception for API errors
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException(this.message, {this.statusCode, this.data});

  @override
  String toString() => message;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isServerError => statusCode != null && statusCode! >= 500;
}

/// API Service with Dio client and interceptors
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;
  final StorageService _storage = StorageService();

  /// In-flight token refresh. Concurrent 401s await this same future and
  /// replay with the winning token (single-flight — FIX-4). Null when no
  /// refresh is running. Completes with the new access token, or null when
  /// the refresh failed.
  Completer<String?>? _refreshCompleter;

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onResponse: _onResponse,
        onError: _onError,
      ),
    );

    // Add logging in debug mode. `debugPrint` is the Flutter-blessed
    // logger that no-ops in release builds, so the API chatter never
    // ships to production logs.
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
        logPrint: (o) => debugPrint('[API] $o'),
      ),
    );
  }

  Dio get dio => _dio;

  /// Add auth headers to requests
  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Get tokens
    final accessToken = await _storage.getAccessToken();
    final companyId = await _storage.getCompanyId();
    final user = await _storage.getUser();

    // Add authorization header
    if (accessToken != null) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }

    // Add tenant headers
    if (companyId != null) {
      options.headers['x-company-id'] = companyId;
    }
    if (user != null) {
      options.headers['x-user-id'] = user.id;
    }

    handler.next(options);
  }

  void _onResponse(Response response, ResponseInterceptorHandler handler) {
    handler.next(response);
  }

  /// Handle errors; on 401, refresh the session (single-flight) and replay.
  Future<void> _onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isRefreshCall =
        err.requestOptions.path == ApiConfig.refreshEndpoint;
    final alreadyRetried = err.requestOptions.extra['authRetried'] == true;

    if (err.response?.statusCode == 401 && !isRefreshCall && !alreadyRetried) {
      final newToken = await _refreshedAccessToken();
      if (newToken != null) {
        final opts = err.requestOptions;
        opts.extra['authRetried'] = true;
        opts.headers['Authorization'] = 'Bearer $newToken';
        try {
          final retryResponse = await _dio.fetch(opts);
          return handler.resolve(retryResponse);
        } on DioException catch (retryErr) {
          // The replay ran through the interceptor chain again, so it is
          // already ApiException-wrapped (authRetried stops a second refresh).
          return handler.reject(retryErr);
        }
      }
    }

    handler.reject(_toApiError(err));
  }

  /// Single-flight refresh: the first 401 kicks off the refresh; concurrent
  /// 401s await the same in-flight future and replay with the winning pair.
  /// Returns null when the refresh failed. Storage is nuked ONLY on a real
  /// 401 from `/refresh` (session over) — a timeout or network drop must not
  /// destroy a still-valid session.
  Future<String?> _refreshedAccessToken() {
    final inFlight = _refreshCompleter;
    if (inFlight != null) return inFlight.future;

    final completer = Completer<String?>();
    _refreshCompleter = completer;

    () async {
      try {
        final refreshToken = await _storage.getRefreshToken();
        if (refreshToken == null) {
          completer.complete(null);
          return;
        }
        final response = await _dio.post(
          ApiConfig.refreshEndpoint,
          data: {'refreshToken': refreshToken},
          options: Options(headers: {'Content-Type': 'application/json'}),
        );
        final data = response.data as Map<String, dynamic>;
        final newAccessToken = data['accessToken'] as String;
        final newRefreshToken = data['refreshToken'] as String;

        await _storage.saveAccessToken(newAccessToken);
        await _storage.saveRefreshToken(newRefreshToken);
        completer.complete(newAccessToken);
      } catch (e) {
        final sessionRevoked =
            e is DioException && e.response?.statusCode == 401;
        // Complete BEFORE touching storage: if clearAll throws (keystore
        // PlatformException) after the refresh failed, every 401 awaiting
        // this completer would hang forever.
        completer.complete(null);
        if (sessionRevoked) {
          try {
            await _storage.clearAll();
          } catch (_) {
            // Best effort — the session is already dead server-side.
          }
        }
      } finally {
        _refreshCompleter = null;
      }
    }();

    return completer.future;
  }

  DioException _toApiError(DioException err) {
    return DioException(
      requestOptions: err.requestOptions,
      error: ApiException(
        _getErrorMessage(err),
        statusCode: err.response?.statusCode,
        data: err.response?.data,
      ),
      type: err.type,
      response: err.response,
    );
  }

  String _getErrorMessage(DioException err) {
    // Check for backend error message
    if (err.response?.data != null) {
      final data = err.response!.data;
      if (data is Map && data['error'] != null) {
        return data['error'].toString();
      }
    }

    // Default messages by type
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
        return 'Tiempo de conexion agotado';
      case DioExceptionType.sendTimeout:
        return 'Tiempo de envio agotado';
      case DioExceptionType.receiveTimeout:
        return 'Tiempo de respuesta agotado';
      case DioExceptionType.connectionError:
        return 'Sin conexion a internet';
      case DioExceptionType.badResponse:
        switch (err.response?.statusCode) {
          case 400:
            return 'Solicitud invalida';
          case 401:
            return 'Sesion expirada';
          case 403:
            return 'Acceso denegado';
          case 404:
            return 'Recurso no encontrado';
          case 500:
            return 'Error del servidor';
          default:
            return 'Error desconocido';
        }
      default:
        return 'Error de conexion';
    }
  }

  // Convenience methods

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.get<T>(path, queryParameters: queryParameters, options: options);
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }
}
