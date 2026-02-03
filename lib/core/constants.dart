/// API Configuration
class ApiConfig {
  // Base URL - change this for production
  static const String baseUrl = 'http://10.0.2.2:3000'; // Android emulator localhost
  // static const String baseUrl = 'http://localhost:3000'; // iOS simulator
  // static const String baseUrl = 'https://your-api.com'; // Production

  // Endpoints
  static const String loginEndpoint = '/api/auth/login';
  static const String refreshEndpoint = '/api/auth/refresh';
  static const String myRouteEndpoint = '/api/mobile/driver/my-route';
  static const String myOrdersEndpoint = '/api/mobile/driver/my-orders';
  static const String routeStopsEndpoint = '/api/route-stops';
  static const String uploadEndpoint = '/api/upload/presigned-url';
  static const String locationEndpoint = '/api/mobile/driver/location';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}

/// Storage Keys
class StorageKeys {
  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String user = 'user';
  static const String companyId = 'company_id';
}

/// App Constants
class AppConstants {
  static const String appName = 'Entregas';
  static const String appVersion = '1.0.0';

  // Location settings
  static const double nearbyDistanceMeters = 100;
  static const int locationUpdateIntervalSeconds = 10;

  // Tracking settings
  static const int trackingIntervalSeconds = 20; // Send location every 20 seconds
  static const int trackingDistanceFilterMeters = 15; // Minimum distance to trigger update
  static const int trackingRetryAttempts = 3; // Number of retry attempts on failure
  static const int trackingRetryDelaySeconds = 5; // Delay between retries
}
