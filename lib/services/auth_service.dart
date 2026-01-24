import '../core/constants.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'storage_service.dart';

/// Authentication service for login, logout, and token management
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();

  User? _currentUser;
  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  /// Initialize - check for existing session
  Future<bool> initialize() async {
    try {
      final user = await _storage.getUser();
      final token = await _storage.getAccessToken();

      if (user != null && token != null) {
        _currentUser = user;
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Login with email and password
  Future<User> login(String email, String password) async {
    try {
      final response = await _api.post(
        ApiConfig.loginEndpoint,
        data: {
          'email': email,
          'password': password,
        },
      );

      final authResponse = AuthResponse.fromJson(
        response.data as Map<String, dynamic>,
      );

      // Save auth data
      await _storage.saveAuthData(
        accessToken: authResponse.accessToken,
        refreshToken: authResponse.refreshToken,
        user: authResponse.user,
      );

      _currentUser = authResponse.user;

      // Verify user is a driver
      if (!authResponse.user.isDriver) {
        await logout();
        throw ApiException(
          'Esta app es solo para conductores',
          statusCode: 403,
        );
      }

      return authResponse.user;
    } on ApiException {
      rethrow;
    } catch (e) {
      if (e is Exception) {
        final message = e.toString();
        if (message.contains('ApiException')) {
          rethrow;
        }
      }
      throw ApiException('Error al iniciar sesion');
    }
  }

  /// Logout and clear session
  Future<void> logout() async {
    _currentUser = null;
    await _storage.clearAll();
  }

  /// Refresh the access token
  Future<bool> refreshToken() async {
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) return false;

      final response = await _api.post(
        ApiConfig.refreshEndpoint,
        data: {'refreshToken': refreshToken},
      );

      final data = response.data as Map<String, dynamic>;
      await _storage.saveAccessToken(data['accessToken'] as String);
      await _storage.saveRefreshToken(data['refreshToken'] as String);

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Get the current access token
  Future<String?> getAccessToken() => _storage.getAccessToken();

  /// Get the current user from storage
  Future<User?> getStoredUser() => _storage.getUser();

  /// Get company ID
  Future<String?> getCompanyId() => _storage.getCompanyId();
}
